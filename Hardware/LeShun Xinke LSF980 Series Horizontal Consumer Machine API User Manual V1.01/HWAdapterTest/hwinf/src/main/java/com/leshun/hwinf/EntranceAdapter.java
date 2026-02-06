package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class EntranceAdapter {
    private static final String TAG  = "leshun_EntranceAdapter";
    private EntranceInf mInterface = null;

    /*初始化门禁（继电器）接口*/
    public boolean init(Context ctx){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.EntranceDevice");
                mInterface = (EntranceInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init();
    }

    /*反初始化门禁（继电器）接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*查询门禁（继电器）开关*/
    public boolean isDoorOpened(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isDoorOpened();
    }

    /*打开门禁（继电器）*/
    public boolean openDoor(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.openDoor();
    }

    /*关闭门禁（继电器）*/
    public boolean closeDoor(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.closeDoor();
    }
}
