package com.leshun.hwinf;

public abstract class WiegandInf {
    public abstract boolean init();
    public abstract void deInit();
    public abstract boolean startRead(HWDataCallBack cb);
    public abstract void stopRead();
    public abstract boolean write(byte[] data, int len);
}
