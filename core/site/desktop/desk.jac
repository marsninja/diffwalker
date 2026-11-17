"""What the desktop app says of itself to its pages: which way it is running, of those
its one program can (against a diffwalker server, or on this computer), and, on this
computer, whose profile is open. A browser tab's app says neither."""
import from "@jac/runtime" {
    jacArrangement,
    jacLeaveLocalUser,
    jacLocalUsers,
    jacUseArrangement,
    jacUseLocalUser,
}

obj Desk {
    has loaded: bool = False,
        # The ways the app can run, the one it is running, and whether its user chose it.
        modes: list[str] = [],
        mode: str = "",
        chosen: bool = True,
        # Whether it runs on local profiles, which replace sign-in; theirs, and the open one.
        local: bool = False,
        profiles: list[str] = [],
        profile: str = "";
}

glob _desk: Desk = Desk();

"""The app as it was last asked."""
def:pub desk -> Desk {
    return _desk;
}

"""Ask the app, and sign the page in as the open profile when there is one."""
async def:pub load_desk -> Desk {
    a: any = await jacArrangement();
    u: any = await jacLocalUsers();
    _desk = Desk(
        loaded=True,
        modes=[str(n) for n in a.names],
        mode=str(a.current),
        chosen=bool(a.chosen),
        local=bool(u.enabled),
        profiles=[str(n) for n in u.users],
        profile=str(u.current),
    );
    return _desk;
}

"""Whether this window runs on local profiles, which replace sign-in."""
def:pub profiles_on -> bool {
    return _desk.local;
}

"""Run the other way from here: the app starts again as it."""
async def:pub choose_mode(name: str) {
    await jacUseArrangement(name);
}

"""Open profile `name`, made the first time, and sign the page in as it."""
async def:pub open_profile(name: str) -> Desk {
    await jacUseLocalUser(name);
    return await load_desk();
}

"""Close the open profile: the picker shows again."""
async def:pub leave_profile {
    await jacLeaveLocalUser();
    window.location.reload();
}
