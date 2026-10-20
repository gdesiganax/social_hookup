package com.example.testing

import android.view.KeyCharacterMap
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isVirtualModifierEvent(event)) {
            return true
        }

        return try {
            super.dispatchKeyEvent(event)
        } catch (error: AssertionError) {
            if (isFlutterMetaStateAssertion(error)) {
                true
            } else {
                throw error
            }
        }
    }

    private fun isVirtualModifierEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN && event.action != KeyEvent.ACTION_UP) {
            return false
        }
        if (!isModifierKey(event.keyCode)) {
            return false
        }

        val isSoftKeyboard = (event.flags and KeyEvent.FLAG_SOFT_KEYBOARD) != 0
        val isVirtualKeyboard = event.deviceId == KeyCharacterMap.VIRTUAL_KEYBOARD
        val hasNoScanCode = event.scanCode == 0

        return isSoftKeyboard || isVirtualKeyboard || hasNoScanCode
    }

    private fun isModifierKey(keyCode: Int): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_SHIFT_LEFT,
            KeyEvent.KEYCODE_SHIFT_RIGHT,
            KeyEvent.KEYCODE_CAPS_LOCK,
            KeyEvent.KEYCODE_CTRL_LEFT,
            KeyEvent.KEYCODE_CTRL_RIGHT,
            KeyEvent.KEYCODE_ALT_LEFT,
            KeyEvent.KEYCODE_ALT_RIGHT,
            KeyEvent.KEYCODE_META_LEFT,
            KeyEvent.KEYCODE_META_RIGHT -> true
            else -> false
        }
    }

    private fun isFlutterMetaStateAssertion(error: AssertionError): Boolean {
        val message = error.message ?: return false
        return message.contains("Unexpected metaState") &&
            message.contains("ACTION", ignoreCase = true) &&
            message.contains("down", ignoreCase = true)
    }
}
