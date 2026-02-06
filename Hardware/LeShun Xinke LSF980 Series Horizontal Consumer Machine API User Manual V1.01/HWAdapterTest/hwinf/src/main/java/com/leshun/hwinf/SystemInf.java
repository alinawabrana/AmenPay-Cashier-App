package com.leshun.hwinf;

import android.content.Context;

public abstract class SystemInf {
    public abstract boolean init(Context ctx);
    public abstract void deInit();
    public abstract float getCPUTemp();
    public abstract void  reboot();
    public abstract String getDeviceUniqueID();
    public abstract boolean hideNavigationBar();
    public abstract boolean showNavigationBar();
    public abstract boolean isNavigationBarShow();
    public abstract boolean isEthernetOn();
    public abstract boolean setEthernetOn(boolean on);
    public abstract boolean isMobileDataOn();
    public abstract boolean setMobileDataOn(boolean on);
    public abstract String   getEthernetMac();
    public abstract String   getWIFIMac();
    public abstract void     silentInstall(Context ctx, String path);
}
