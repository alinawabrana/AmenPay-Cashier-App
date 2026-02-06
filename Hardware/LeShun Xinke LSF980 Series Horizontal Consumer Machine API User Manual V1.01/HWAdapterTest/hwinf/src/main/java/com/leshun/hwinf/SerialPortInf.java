package com.leshun.hwinf;

public abstract class SerialPortInf {
    public abstract boolean init(String node, int bit_rate);
    public abstract void deInit();
    public abstract boolean writeData(byte[] data, int length);
    public abstract boolean startRead(HWDataCallBack cb);
    public abstract void stopRead();
}
