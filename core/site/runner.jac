import from "@jac/runtime" { RemoteRejected }

glob _running: dict[str, bool] = {};

def:pub is_running(pr_id: str) -> bool;
async def:pub launch_review(pr_id: str, focus: str = "") -> bool;
