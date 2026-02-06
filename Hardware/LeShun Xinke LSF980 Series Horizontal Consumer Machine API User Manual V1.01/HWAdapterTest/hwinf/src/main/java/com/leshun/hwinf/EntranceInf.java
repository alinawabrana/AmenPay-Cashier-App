package com.leshun.hwinf;

public abstract class EntranceInf {
    public abstract boolean init();
    public abstract void    deInit();
    public abstract boolean isDoorOpened();
    public abstract boolean openDoor();
    public abstract boolean closeDoor();
}
