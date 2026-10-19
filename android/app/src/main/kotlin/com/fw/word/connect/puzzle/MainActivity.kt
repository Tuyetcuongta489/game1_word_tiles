package com.fw.word.connect.puzzle

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Pre-initialize DecorView so that PhoneWindow's content container (android.R.id.content)
        // is installed before theme switching, plugin attachment, and SDK lifecycle callbacks run.
        window.decorView
        super.onCreate(savedInstanceState)
    }
}
