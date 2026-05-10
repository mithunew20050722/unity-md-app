package com.unityteam.unity_md;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

/**
 * Phone boot වූ විට BotService start කරනවා.
 * SharedPreferences ල userId save වෙලා තියෙනවා නම්
 * server ට reconnect request යනවා.
 */
public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "UNITY_BOOT";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (action == null) return;

        if (action.equals(Intent.ACTION_BOOT_COMPLETED) ||
            action.equals("android.intent.action.QUICKBOOT_POWERON") ||
            action.equals("com.htc.intent.action.QUICKBOOT_POWERON")) {

            Log.d(TAG, "Boot received — checking saved session...");

            // Check if user has a saved session
            SharedPreferences prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            );
            // Flutter shared_preferences uses "flutter." prefix
            String userId = prefs.getString("flutter.userId", null);

            if (userId != null && !userId.isEmpty()) {
                Log.d(TAG, "Session found: " + userId + " — starting BotService");
                Intent serviceIntent = new Intent(context, BotService.class);
                serviceIntent.putExtra("userId", userId);
                serviceIntent.putExtra("autoStart", true);

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent);
                } else {
                    context.startService(serviceIntent);
                }
            } else {
                Log.d(TAG, "No saved session — skipping auto start");
            }
        }
    }
}
