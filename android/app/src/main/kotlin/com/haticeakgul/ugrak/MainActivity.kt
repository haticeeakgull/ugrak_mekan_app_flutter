package com.haticeakgul.ugrak

import android.view.LayoutInflater
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Ad Factory'leri kaydet
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "cafeCardStyle",
            CafeCardNativeAdFactory(layoutInflater)
        )
        
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "postCardStyle",
            PostCardNativeAdFactory(layoutInflater)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        
        // Native Ad Factory'leri temizle
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "cafeCardStyle")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "postCardStyle")
    }
}

class CafeCardNativeAdFactory(private val layoutInflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_cafe_card, null) as NativeAdView

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView.text = nativeAd.body
        adView.bodyView = bodyView

        // Call to Action
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        ctaView.text = nativeAd.callToAction
        adView.callToActionView = ctaView

        // Media View (Ana görsel)
        val mediaView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_media)
        adView.mediaView = mediaView

        // Icon
        val iconView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_icon)
        adView.iconView = iconView

        // NativeAd'i view'e ata
        adView.setNativeAd(nativeAd)

        return adView
    }
}

class PostCardNativeAdFactory(private val layoutInflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_post_card, null) as NativeAdView

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView.text = nativeAd.body
        adView.bodyView = bodyView

        // Advertiser (Reklamveren)
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        advertiserView.text = nativeAd.advertiser
        adView.advertiserView = advertiserView

        // Call to Action
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        ctaView.text = nativeAd.callToAction
        adView.callToActionView = ctaView

        // Media View (Arka plan görseli)
        val mediaView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_media)
        adView.mediaView = mediaView

        // Icon
        val iconView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_icon)
        adView.iconView = iconView

        // NativeAd'i view'e ata
        adView.setNativeAd(nativeAd)

        return adView
    }
}
