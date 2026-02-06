package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class LedAdapter {
    private static final String TAG  = "leshun_LedAdapter";
    private LedInf mInterface = null;

    /*初始化补光灯类设备接口*/
    public boolean init(Context ctx){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.LedDevice");
                mInterface = (LedInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init();
    }

    /*反初始化补光灯类设备接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*查询白光补光灯设备接口*/
    public boolean isWhiteLedOpened(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isWhiteLedOpened();
    }
    /*打开关闭白光补光灯设备接口*/
    public boolean setWhiteLed(boolean open){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setWhiteLed(open);
    }
    /*查询红外补光灯设备接口
    * 部分设备使用USB摄像头，红外补光灯由摄像头管理，可忽略此接口*/
    public boolean isIRLedOpened(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isIRLedOpened();
    }
    /*打开关闭红外补光灯设备接口
     * 部分设备使用USB摄像头，红外补光灯由摄像头管理，可忽略此接口*/
    public boolean setIRLed(boolean open){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setIRLed(open);
    }
    /*查询灯带（其他LED灯）设备接口
     * 部分设备没有此硬件，可忽略此接口*/
    public boolean isColorLedOpened(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isColorLedOpened();
    }
    /*打开关闭灯带（其他LED灯）设备接口
     * 部分设备没有此硬件，可忽略此接口*/
    public boolean setColorLed(boolean open){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setColorLed(open);
    }
    /*查询屏幕物理亮度设备接口
    * 返回当前屏幕亮度值，范围0 -- 255 */
    public int getScreenBrightness(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -1;
        }
        return mInterface.getScreenBrightness();
    }
    /*设置屏幕物理亮度设备接口
    * level：0 -- 255 */
    public boolean setScreenBrightness(int level){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setScreenBrightness(level);
    }
}
