"""
LangGraph implementation for task orchestration.

Builds a state graph that manages the task execution lifecycle with planning
and execution nodes. Supports interrupts for pausing/resuming execution.
"""

from __future__ import annotations

import json
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command, interrupt

from .graph_state import AgentState
from .schemas import ExecutorStep
from .planner import build_planner_agent
from .coder import build_coder_agent


def build_agent_graph(task_manager, ws_manager, config, execute_tool_calls):
    """
    Build the LangGraph for task orchestration.

    Args:
        task_manager: TaskManager instance for accessing task data
        ws_manager: WebSocketManager instance for sending messages
        config: Config instance with LLM configurations
        execute_tool_calls: Async function to execute tool calls with batching

    Returns:
        Compiled LangGraph
    """
    planner_agent = build_planner_agent(
        config.planner_llm.model,
        config.planner_llm.base_url
    )
    coder_agent = build_coder_agent(
        config.coder_llm.model,
        config.coder_llm.base_url
    )

    async def ensure_plan(state: AgentState):
        """
        Ensure the task has a plan. Runs once per task.

        Args:
            state: Current agent state

        Returns:
            Updated state with plan
        """
        task = task_manager.get_task(state["task_id"])
        tools = config.get_commands_for_task(task.kind)

        if "plan" in state:
            return state

        plan_prompt = (
            f"Task: {task.prompt}\n\n"
            f"Available tools: {[t['name'] for t in tools]}\n"
            "Return a plan."
        )
        plan_result = await planner_agent.run(plan_prompt)
        state["plan"] = plan_result.data.model_dump()
        state["phase"] = "execute"
        print(f"[PLANNER] Plan generated: {state['plan']['goal']}")
        return state

    async def decide_next(state: AgentState):
        """
        Decide the next action using the coder agent.

        Args:
            state: Current agent state

        Returns:
            Updated state with last_step
        """
        task = task_manager.get_task(state["task_id"])
        tools = config.get_commands_for_task(task.kind)

        exec_prompt = (
            f"Task: {task.prompt}\n\n"
            f"Plan: {json.dumps(state.get('plan', {}), indent=2)}\n\n"
            f"Available tools: {json.dumps(tools)}\n\n"
            f"Conversation so far: {json.dumps(task.history[-30:], indent=2)}\n\n"
            "Return the next ExecutorStep."
        )
        step_result = await coder_agent.run(exec_prompt)
        state["last_step"] = step_result.data.model_dump()
        print(f"[CODER] Decision status: {state['last_step']['status']}")
        return state

    async def act(state: AgentState):
        """
        Execute the decided action.

        Args:
            state: Current agent state

        Returns:
            Command to control graph flow or updated state
        """
        task = task_manager.get_task(state["task_id"])
        step = ExecutorStep.model_validate(state["last_step"])

        if step.status == "complete":
            # Task is complete
            await ws_manager.send_to_client(task.client_id, {
                "type": "task_update",
                "task_id": task.task_id,
                "status": "completed",
                "result": {"message": step.final_message},
            })
            task_manager.complete_task(task.task_id, {"message": step.final_message})
            return Command(goto=END)

        if step.status == "need_user":
            # Pause graph and return the question
            interrupt({"kind": "user", "question": step.user_question})
            return state

        # status == "continue" - execute tool calls
        tool_calls = [tc.model_dump() for tc in step.tool_calls]
        outcome = await execute_tool_calls(task, tool_calls)

        if outcome.get("status") == "waiting_for_command":
            # Pause for CC-side command
            interrupt({"kind": "command", "call_id": outcome["call_id"]})
            return state

        # All tools were server-side, continue to next decision
        return state

    # Build the graph
    g = StateGraph(AgentState)
    g.add_node("ensure_plan", ensure_plan)
    g.add_node("decide_next", decide_next)
    g.add_node("act", act)

    g.add_edge(START, "ensure_plan")
    g.add_edge("ensure_plan", "decide_next")
    g.add_edge("decide_next", "act")
    g.add_edge("act", "decide_next")

    return g.compile()
