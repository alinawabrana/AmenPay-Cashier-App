package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class ProximityAdapter {
    private static final String TAG  = "leshun_ProximityAdapter";
    private ProximityInf mInterface = null;

    /*初始化距离传感接口， 失败返回false(设备可能没有距离传感器)*/
    public boolean init(Context ctx) {
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.ProximityDevice");
                mInterface = (ProximityInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init(ctx);
    }

    public void deInit() {
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*开始监听距离传感器，有变化（接近、远离）会回调，回调数据data[0] == 0x1 表示接近；data[0] == 0 表示远离*/
    public boolean startMonitor(HWDataCallBack cb) {
        if(cb == null){
            Log.w(TAG, "startMonitor need HWDataCallBack!");
            return  false;
        }
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.startMonitor(cb);
    }

    /*停止监听*/
    public void stopMonitor() {
        if(mInterface != null)
            mInterface.stopMonitor();
    }
}
