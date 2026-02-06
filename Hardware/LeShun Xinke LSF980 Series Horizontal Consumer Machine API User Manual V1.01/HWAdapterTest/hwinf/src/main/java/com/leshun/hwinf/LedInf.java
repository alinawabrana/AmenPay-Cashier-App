package com.leshun.hwinf;

public abstract class LedInf {
    public abstract boolean init();
    public abstract void    deInit();
    public abstract boolean isWhiteLedOpened();
    public abstract boolean setWhiteLed(boolean open);
    public abstract boolean isIRLedOpened();
    public abstract boolean setIRLed(boolean open);
    public abstract boolean isColorLedOpened();
    public abstract boolean setColorLed(boolean open);
    public abstract int getScreenBrightness();
    public abstract boolean setScreenBrightness(int level);
}
