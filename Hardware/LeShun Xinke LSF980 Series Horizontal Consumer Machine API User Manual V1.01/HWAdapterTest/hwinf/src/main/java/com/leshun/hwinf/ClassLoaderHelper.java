package com.leshun.hwinf;

import android.content.Context;
import android.os.Environment;
import android.util.Log;
import java.io.File;
import dalvik.system.DexClassLoader;

class ClassLoaderHelper {
    private static final String TAG = "leshun_ClassLoader";
    static DexClassLoader mClassLoader = null;
    static DexClassLoader getCalssLoader(Context ctx){
        if(mClassLoader == null){
            File f1 = new File("/system/framework/com.leshun.hwdevice.jar");
            File f2 = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/com.leshun.hwdevice.jar");
            String dex_path = null;
            String tmpPath = ctx.getDir("jar", 0).getAbsolutePath();
            if(f1.exists())
                dex_path = f1.getAbsolutePath();
            else if(f2.exists())
                dex_path = f2.getAbsolutePath();
            if(dex_path == null){
                Log.w(TAG, "the com.leshun.hwdevice.jar not exist!");
                return null;
            }
            Log.d(TAG, "jar url is: " + dex_path);
            mClassLoader = new DexClassLoader(dex_path, tmpPath, null, ctx.getClassLoader());
        }
        return mClassLoader;
    }
}
