package com.leshun.hwinf;

import android.content.Context;
import android.util.Log;

import dalvik.system.DexClassLoader;

public class SystemAdapter {
    private static final String TAG  = "leshun_SystemAdapter";
    private SystemInf mInterface = null;

    /*初始化系统辅助接口*/
    public boolean init(Context ctx){
        if(mInterface == null){
            try{
                DexClassLoader cls_loader = ClassLoaderHelper.getCalssLoader(ctx);
                if(cls_loader == null)
                    return false;
                Class<?> myClass = cls_loader.loadClass("com.leshun.hwinf.SystemDevice");
                mInterface = (SystemInf) myClass.newInstance();
            } catch (Exception e){
                Log.e(TAG, "load class error: " + e);
                return false;
            }
        }
        return mInterface.init(ctx);
    }

    /*反初始化系统辅助接口*/
    public void deInit(){
        if(mInterface != null){
            mInterface.deInit();
            mInterface = null;
        }
    }

    /*获取设备CPU温度接口*/
    public float getCPUTemp(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return -1;
        }
        return mInterface.getCPUTemp();
    }

    /*重启设备接口*/
    public void reboot(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return;
        }
        mInterface.reboot();
    }

    /*获取设备唯一标识号接口
    * 一般指IMEI 或者 SN 或者 MAC地址等*/
    public String getDeviceUniqueID(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return "Unknown";
        }
        return mInterface.getDeviceUniqueID();
    }

    /*隐藏导航栏(系统层隐藏，对所有Activity有效)*/
    public boolean hideNavigationBar(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.hideNavigationBar();
    }

    /*查询导航栏开关*/
    public boolean isNavigationBarShow(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isNavigationBarShow();
    }

    /*显示导航栏(取消隐藏导航栏，回到正常模式，Activity可通过Android属性设置导航栏的隐藏、显示、滑动显示)*/
    public boolean showNavigationBar(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.showNavigationBar();
    }

    /*查询以太网开关*/
    public  boolean isEthernetOn(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isEthernetOn();
    }
    /*设置以太网开关*/
    public  boolean setEthernetOn(boolean on){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setEthernetOn(on);
    }
    /*查询数据连接开关*/
    public  boolean isMobileDataOn(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.isMobileDataOn();
    }
    /*设置数据连接开关*/
    public  boolean setMobileDataOn(boolean on){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return false;
        }
        return mInterface.setMobileDataOn(on);
    }
    /*获取以太网MAC，有可能返回NULL*/
    public  String   getEthernetMac(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return null;
        }
        return mInterface.getEthernetMac();
    }

    /*获取WIFI MAC，有可能返回NULL*/
    public  String   getWIFIMac(){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return null;
        }
        return mInterface.getWIFIMac();
    }

    /*静默安装，参数path为安装包路径（不要有空格、中文和特殊字符）*/
    public void silentInstall(Context ctx, String path){
        if(mInterface == null){
            Log.w(TAG, "mInterface is null, call init first!");
            return;
        }
        mInterface.silentInstall(ctx, path);
    }

}
