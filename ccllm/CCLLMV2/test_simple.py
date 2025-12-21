import os, asyncio
from dataclasses import dataclass
from typing import Literal, Optional, Any

from pydantic import BaseModel, Field
from pydantic_ai import Agent, ModelRetry

os.environ.setdefault("OLLAMA_BASE_URL", "http://localhost:11434/v1")


@dataclass
class Deps:
    mode: str = "stub"
    task_id: str = "ctx_ok"


# ---- typed args for a "codegen tool" ----
class CodegenArgs(BaseModel):
    language: Literal["lua"]
    filename: str = Field(..., min_length=1, max_length=64)
    code: str = Field(..., min_length=1, max_length=4000)  # keep it small for test


class Payload(BaseModel):
    kind: Literal["tool", "final"]
    explanation: str = Field(..., min_length=1, max_length=160)

    # tool fields
    tool: Optional[Literal["print_codegen"]] = None
    args: Optional[CodegenArgs] = None

    # final fields
    success: Optional[bool] = None
    message: Optional[str] = None


class Wrapped(BaseModel):
    name: Literal["tool_request", "final_result"]
    parameters: Payload


agent = Agent(
    "ollama:qwen2.5-coder:14b",
    deps_type=Deps,
    output_type=Wrapped,
    retries=3,
    system_prompt=(
        "Return ONLY valid JSON:\n"
        '{"name":"tool_request|final_result","parameters":{...}}\n'
        "No markdown. No extra keys.\n"
        "\n"
        "Step 1) Return name='tool_request' with parameters:\n"
        "  kind='tool'\n"
        "  explanation: short status (<=160 chars)\n"
        "  tool='print_codegen'\n"
        "  args.language='lua'\n"
        "  args.filename='hello.lua'\n"
        "  args.code = Lua code that takes in two args and prints out all primes inbetween those two numbers \n"
        "  The Lua must be valid\n"
        "\n"
        "Step 2) After TOOL_RESULT, return name='final_result' with parameters:\n"
        "  kind='final'\n"
        "  explanation: short summary\n"
        "  success=true\n"
        "  message must include the token you received\n"
    ),
)


def get_parsed(r: Any) -> Wrapped:
    for attr in ("data", "output", "result"):
        v = getattr(r, attr, None)
        if isinstance(v, Wrapped):
            return v
        if callable(v):
            try:
                out = v()
                if isinstance(out, Wrapped):
                    return out
            except TypeError:
                pass
    raise AttributeError("Couldn't find parsed output on result.")


async def print_codegen(deps: Deps, args: CodegenArgs) -> str:
    print("\n=== GENERATED FILE ===")
    print("language:", args.language)
    print("filename:", args.filename)
    print("--- code ---")
    print(args.code.rstrip())
    print("------------")
    return f"TOKEN_CODEGEN_9a1d deps.task_id={deps.task_id}"


async def main() -> None:
    deps = Deps()

    # Step 1: request codegen
    r1 = await agent.run("Go.", deps=deps)
    w1 = get_parsed(r1)
    p1 = w1.parameters

    if w1.name != "tool_request" or p1.kind != "tool" or p1.tool != "print_codegen" or p1.args is None:
        raise ModelRetry("Expected tool_request with tool='print_codegen' and args.")

    print("[EXPLANATION]", p1.explanation)

    # Run the "tool"
    tool_result = await print_codegen(deps, p1.args)
    print("[TOOL_RESULT]", tool_result)

    # Step 2: final
    r2 = await agent.run(f"TOOL_RESULT: {tool_result}", deps=deps)
    w2 = get_parsed(r2)
    p2 = w2.parameters

    if w2.name != "final_result" or p2.kind != "final" or not p2.success or not p2.message:
        raise ModelRetry("Expected final_result with success=true and message.")

    print("[EXPLANATION]", p2.explanation)
    print("[FINAL]", {"success": p2.success, "message": p2.message})


if __name__ == "__main__":
    asyncio.run(main())
