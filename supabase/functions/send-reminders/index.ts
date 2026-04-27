// Supabase Edge Function: send-reminders
// Deploy: supabase functions deploy send-reminders
// Schedule via pg_cron or Supabase cron jobs (every minute)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (_req) => {
  const now = new Date().toISOString()

  // Fetch unsent reminders due now
  const { data: reminders, error } = await supabase
    .from('reminders')
    .select('*, tasks(title, deadline), user_profiles(fcm_token)')
    .lte('remind_at', now)
    .eq('is_sent', false)
    .limit(100)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const results = await Promise.allSettled(
    (reminders ?? []).map(async (reminder: any) => {
      const fcmToken = reminder.user_profiles?.fcm_token
      if (!fcmToken) return

      // Send FCM push notification
      await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `key=${Deno.env.get('FCM_SERVER_KEY')}`,
        },
        body: JSON.stringify({
          to: fcmToken,
          notification: {
            title: `⏰ Task due soon: ${reminder.tasks?.title}`,
            body: reminder.tasks?.deadline
              ? `Due at ${new Date(reminder.tasks.deadline).toLocaleTimeString()}`
              : 'Your task is due soon',
          },
          data: { taskId: reminder.task_id },
        }),
      })

      // Mark as sent
      await supabase
        .from('reminders')
        .update({ is_sent: true })
        .eq('id', reminder.id)
    })
  )

  return new Response(
    JSON.stringify({ processed: results.length }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
