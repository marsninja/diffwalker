import from "@jac/runtime" {
    jacArrangement,
    jacLeaveLocalUser,
    jacLocalUsers,
    jacUseArrangement,
    jacUseLocalUser,
}

obj Desk {
    has loaded: bool = False,
        modes: list[str] = [],
        mode: str = "",
        chosen: bool = True,
        local: bool = False,
        profiles: list[str] = [],
        profile: str = "";
}

glob _desk: Desk = Desk();
def:pub desk -> Desk;
async def:pub load_desk -> Desk;
def:pub profiles_on -> bool;
async def:pub choose_mode(name: str);
async def:pub open_profile(name: str) -> Desk;
async def:pub leave_profile;
