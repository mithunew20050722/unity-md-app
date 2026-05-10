package com.unityteam.unity_md;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Background service — bot connected ව තබාගන්නවා.
 * Data on වූ විට server ට reconnect request යනවා.
 * ෆෝග්‍රවුන්ඩ් notification show කරනවා (Android requirement).
 */
public class BotService extends Service {
    private static final String TAG        = "UNITY_SERVICE";
    private static final String CH_ID     = "unity_bot_channel";
    private static final String BASE_URL  = "https://unity.up.railway.app/api/app";
    private static final int    NOTIF_ID  = 1001;

    private ScheduledExecutorService _scheduler;
    private String _userId;
    private String _firebaseToken;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            _userId = intent.getStringExtra("userId");
        }

        // Load from prefs if not in intent
        if (_userId == null) {
            SharedPreferences prefs = getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            );
            _userId = prefs.getString("flutter.userId", null);
        }

        if (_userId == null) {
            Log.d(TAG, "No userId — stopping service");
            stopSelf();
            return START_NOT_STICKY;
        }

        Log.d(TAG, "BotService started for: " + _userId);

        // Show foreground notification
        startForeground(NOTIF_ID, buildNotification("Bot Active", "UNITY-MD is running..."));

        // Reconnect immediately
        reconnectAsync();

        // Schedule periodic keep-alive every 5 minutes
        _scheduler = Executors.newSingleThreadScheduledExecutor();
        _scheduler.scheduleAtFixedRate(
            this::reconnectAsync, 5, 5, TimeUnit.MINUTES
        );

        return START_STICKY; // Restart if killed
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (_scheduler != null) _scheduler.shutdown();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    // ── Reconnect to Railway server ───────────────────────────
    private void reconnectAsync() {
        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                // Get fresh Firebase token from prefs
                SharedPreferences prefs = getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE
                );
                _firebaseToken = prefs.getString("flutter.firebaseToken", null);

                URL url = new URL(BASE_URL + "/reconnect");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setRequestProperty("Authorization", "Bearer " + _firebaseToken);
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(15000);
                conn.setDoOutput(true);

                JSONObject body = new JSONObject();
                body.put("userId", _userId);

                byte[] bodyBytes = body.toString().getBytes(StandardCharsets.UTF_8);
                try (OutputStream os = conn.getOutputStream()) {
                    os.write(bodyBytes);
                }

                int code = conn.getResponseCode();
                Log.d(TAG, "Reconnect response: " + code);

                if (code == 200) {
                    updateNotification("Bot Active ✅", "Connected to WhatsApp");
                } else {
                    updateNotification("Bot Warning", "Server response: " + code);
                }

                conn.disconnect();

            } catch (Exception e) {
                Log.e(TAG, "Reconnect failed: " + e.getMessage());
                updateNotification("Bot Offline", "Retrying when network available...");
            }
        });
    }

    // ── Notification helpers ──────────────────────────────────
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                CH_ID,
                "UNITY-MD Bot",
                NotificationManager.IMPORTANCE_LOW
            );
            ch.setDescription("Bot connection status");
            ch.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    private Notification buildNotification(String title, String text) {
        Intent tapIntent = new Intent(this, MainActivity.class);
        tapIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pi = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        return new NotificationCompat.Builder(this, CH_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build();
    }

    private void updateNotification(String title, String text) {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm != null) nm.notify(NOTIF_ID, buildNotification(title, text));
    }
}
