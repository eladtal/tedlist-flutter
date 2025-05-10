package io.flutter.app;

import androidx.multidex.MultiDexApplication;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback;
import io.flutter.plugins.GeneratedPluginRegistrant;

/**
 * Flutter MultiDex Application for API level < 21
 */
public class FlutterMultiDexApplication extends MultiDexApplication implements PluginRegistrantCallback {
    @Override
    public void registerWith(PluginRegistry registry) {
        // GeneratedPluginRegistrant.registerWith(registry);
    }
} 