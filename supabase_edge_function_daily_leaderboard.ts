// Supabase Edge Function - Günlük Leaderboard Güncelleme
// Her gün 03:00'te çalışır

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    console.log('🔄 Günlük leaderboard güncelleme başlatılıyor...')

    // 1. Tüm kullanıcıların puanını güncelle
    const { error: updateError } = await supabase.rpc('update_all_user_points')
    
    if (updateError) {
      console.error('❌ Puan güncelleme hatası:', updateError)
      throw updateError
    }

    console.log('✅ Kullanıcı puanları güncellendi')

    // 2. Günlük snapshot oluştur
    const { error: snapshotError } = await supabase.rpc('create_daily_leaderboard_snapshot')
    
    if (snapshotError) {
      console.error('❌ Snapshot oluşturma hatası:', snapshotError)
      throw snapshotError
    }

    console.log('✅ Günlük snapshot oluşturuldu')

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Leaderboard başarıyla güncellendi',
        timestamp: new Date().toISOString()
      }),
      { 
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Hata:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

// Supabase Dashboard'da bu fonksiyonu oluştur:
// 1. Edge Functions > New Function
// 2. İsim: daily-leaderboard-update
// 3. Bu kodu yapıştır
// 4. Deploy et
// 5. Cron Jobs > New Cron Job
//    - Schedule: 0 3 * * * (Her gün 03:00)
//    - Function: daily-leaderboard-update
