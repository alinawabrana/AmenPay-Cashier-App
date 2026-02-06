package com.leshun.hwinf;

import android.content.Context;

public abstract class ProximityInf {
    public abstract boolean init(Context ctx);
    public abstract void    deInit();
    public abstract boolean startMonitor(HWDataCallBack cb);
    public abstract void stopMonitor();
}
