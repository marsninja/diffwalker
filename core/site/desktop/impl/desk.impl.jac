impl desk -> Desk {
    return _desk;
}

impl load_desk -> Desk {
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

impl profiles_on -> bool {
    return _desk.local;
}

impl choose_mode(name: str) {
    await jacUseArrangement(name);
}

impl open_profile(name: str) -> Desk {
    await jacUseLocalUser(name);
    return await load_desk();
}

impl leave_profile {
    await jacLeaveLocalUser();
    window.location.reload();
}
