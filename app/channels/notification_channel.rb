class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    # Cleanup when channel is unsubscribed
  end

  # Broadcast a notification to a specific user
  def self.notify(user, type:, title:, body:, data: {})
    broadcast_to(user, {
      id: SecureRandom.uuid,
      type: type,
      title: title,
      body: body,
      data: data,
      created_at: Time.current.iso8601
    })
  end
end
