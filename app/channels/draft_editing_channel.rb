class DraftEditingChannel < ApplicationCable::Channel
  def subscribed
    @draft_response = DraftResponse.find(params[:draft_response_id])
    stream_from "draft_editing_#{@draft_response.id}"

    # Broadcast presence
    broadcast_presence(:joined)
  end

  def unsubscribed
    if @draft_response
      # Auto-unlock if this user held the lock
      if @draft_response.locked_by_id == current_user.id
        @draft_response.update(locked_by: nil, locked_at: nil)
      end
      broadcast_presence(:left)
    end
  end

  def cursor_position(data)
    ActionCable.server.broadcast("draft_editing_#{@draft_response.id}", {
      type: "cursor",
      user_id: current_user.id,
      user_name: "#{current_user.first_name} #{current_user.last_name}",
      position: data["position"],
      selection: data["selection"]
    })
  end

  def content_update(data)
    ActionCable.server.broadcast("draft_editing_#{@draft_response.id}", {
      type: "content_update",
      user_id: current_user.id,
      user_name: "#{current_user.first_name} #{current_user.last_name}",
      content: data["content"],
      timestamp: Time.current.iso8601
    })
  end

  private

  def broadcast_presence(action)
    ActionCable.server.broadcast("draft_editing_#{@draft_response.id}", {
      type: "presence",
      action: action.to_s,
      user_id: current_user.id,
      user_name: "#{current_user.first_name} #{current_user.last_name}",
      timestamp: Time.current.iso8601
    })
  end
end
