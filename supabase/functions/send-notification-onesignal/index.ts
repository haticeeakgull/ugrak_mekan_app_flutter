import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  user_id: string
  title: string
  body: string
  type: 'message' | 'notification' | 'follow' | 'like' | 'comment'
  target_id?: string
  sender_id?: string // Mesaj gönderen kişinin ID'si (gruplama için)
  data?: Record<string, any>
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase client oluştur
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Request body'yi al
    const payload: NotificationPayload = await req.json()
    const { user_id, title, body, type, target_id, sender_id, data } = payload

    console.log('📬 Bildirim gönderiliyor:', { user_id, title, type, target_id })

    // 1. Kullanıcının OneSignal Player ID'sini ve bildirim ayarını al
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('onesignal_player_id, notifications_enabled')
      .eq('id', user_id)
      .single()

    if (profileError) {
      throw new Error(`Profil bulunamadı: ${profileError.message}`)
    }

    // 2. Bildirimler kapalıysa gönderme
    if (!profile.notifications_enabled) {
      console.log('⚠️ Kullanıcının bildirimleri kapalı')
      return new Response(
        JSON.stringify({ success: false, message: 'Bildirimler kapalı' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. OneSignal Player ID yoksa gönderme
    if (!profile.onesignal_player_id) {
      console.log('⚠️ OneSignal Player ID bulunamadı')
      return new Response(
        JSON.stringify({ success: false, message: 'OneSignal Player ID yok' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. OneSignal'e bildirim gönder
    const oneSignalAppId = Deno.env.get('ONESIGNAL_APP_ID')
    const oneSignalApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')

    if (!oneSignalAppId || !oneSignalApiKey) {
      throw new Error('OneSignal credentials tanımlı değil')
    }

    // Deep link URL'lerini oluştur
    let deepLinkUrl = ''
    switch (type) {
      case 'message':
        // Mesaj bildirimi: chat detay sayfasına git
        deepLinkUrl = `ugrakmekan://chat/${target_id}`
        break
      case 'follow':
      case 'like':
      case 'comment':
      case 'notification':
        // Diğer bildirimler: bildirimler sayfasına git
        deepLinkUrl = 'ugrakmekan://notifications'
        break
      default:
        // Varsayılan: ana sayfa
        deepLinkUrl = 'ugrakmekan://home'
    }

    // Mesaj gruplaması için collapse_id (aynı chat'ten gelen mesajlar gruplanır)
    const collapseId = type === 'message' && sender_id
      ? `chat_${sender_id}_${target_id}`
      : undefined

    const oneSignalPayload: any = {
      app_id: oneSignalAppId,
      include_player_ids: [profile.onesignal_player_id], // Player ID kullan
      headings: { en: title },
      contents: { en: body },
      data: {
        type: type,
        target_id: target_id || '',
        sender_id: sender_id || '',
        deep_link: deepLinkUrl,
        ...data,
      },
      priority: 10,
      // Deep link ayarları
      url: deepLinkUrl,
      app_url: deepLinkUrl,
      // Android için gruplama
      android_group: type === 'message' && target_id ? `chat_${target_id}` : undefined,
      android_group_message: type === 'message' ? { en: '$[notif_count] yeni mesaj' } : undefined,
      // iOS için gruplama
      thread_id: type === 'message' && target_id ? `chat_${target_id}` : undefined,
      // Mesaj gruplaması için collapse_id
      collapse_id: collapseId,
    }

    // Undefined değerleri temizle
    Object.keys(oneSignalPayload).forEach(key =>
      oneSignalPayload[key] === undefined && delete oneSignalPayload[key]
    )

    console.log('📤 OneSignal payload:', JSON.stringify(oneSignalPayload, null, 2))

    const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${oneSignalApiKey}`,
      },
      body: JSON.stringify(oneSignalPayload),
    })

    const oneSignalResult = await oneSignalResponse.json()

    console.log('📥 OneSignal response:', JSON.stringify(oneSignalResult, null, 2))

    if (oneSignalResult.id) {
      console.log('✅ Bildirim başarıyla gönderildi:', oneSignalResult.id)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Bildirim gönderildi',
          notification_id: oneSignalResult.id
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      console.error('❌ OneSignal hatası:', oneSignalResult)
      console.error('❌ OneSignal response status:', oneSignalResponse.status)
      return new Response(
        JSON.stringify({
          success: false,
          error: oneSignalResult,
          status: oneSignalResponse.status,
          message: oneSignalResult.errors || oneSignalResult.error || 'OneSignal API hatası'
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }
  } catch (error) {
    console.error('❌ Hata:', error)
    console.error('❌ Hata detayı:', error.stack)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
