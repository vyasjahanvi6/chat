class ConversationReplyMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_SENDER_EMAIL', 'Chatwoot <accounts@chatwoot.com>')
  layout :choose_layout

  def reply_with_summary(conversation, message_queued_time)
    return unless smtp_config_set_or_development?

    init_conversation_attributes(conversation)
    return if conversation_already_viewed?

    recap_messages = @conversation.messages.chat.where('created_at < ?', message_queued_time).last(10)
    new_messages = @conversation.messages.chat.where('created_at >= ?', message_queued_time)
    @messages = recap_messages + new_messages
    @messages = @messages.select(&:email_reply_summarizable?)

    mail({
           to: @contact&.email,
           from: from_email_with_name,
           reply_to: reply_email,
           subject: mail_subject,
           message_id: custom_message_id,
           in_reply_to: in_reply_to_email
         })
  end

  def reply_without_summary(conversation, message_queued_time)
    return unless smtp_config_set_or_development?

    init_conversation_attributes(conversation)
    return if conversation_already_viewed?

    @messages = @conversation.messages.chat.where(message_type: [:outgoing, :template]).where('created_at >= ?', message_queued_time)
    @messages = @messages.reject { |m| m.template? && !m.input_csat? }
    return false if @messages.count.zero?

    mail({
           to: @contact&.email,
           from: from_email_with_name,
           reply_to: reply_email,
           subject: mail_subject,
           message_id: custom_message_id,
           in_reply_to: in_reply_to_email
         })
  end

  def conversation_transcript(conversation, to_email)
    return unless smtp_config_set_or_development?

    init_conversation_attributes(conversation)

    @messages = @conversation.messages.chat.select(&:conversation_transcriptable?)

    mail({
           to: to_email,
           from: from_email_with_name,
           subject: "[##{@conversation.display_id}] #{I18n.t('conversations.reply.transcript_subject')}"
         })
  end

  private

  def init_conversation_attributes(conversation)
    @conversation = conversation
    @account = @conversation.account
    @contact = @conversation.contact
    @agent = @conversation.assignee
    @inbox = @conversation.inbox
  end

  def should_use_conversation_email_address?
    @inbox.inbox_type == 'Email' || inbound_email_enabled?
  end

  def conversation_already_viewed?
    # whether contact already saw the message on widget
    return unless @conversation.contact_last_seen_at
    return unless last_outgoing_message&.created_at

    @conversation.contact_last_seen_at > last_outgoing_message&.created_at
  end

  def last_outgoing_message
    @conversation.messages.chat.where.not(message_type: :incoming)&.last
  end

  def assignee_name
    @assignee_name ||= @agent&.available_name || 'Notifications'
  end

  def mail_subject
    return "Re: #{incoming_mail_subject}" if incoming_mail_subject

    subject_line = I18n.t('conversations.reply.email_subject')
    "[##{@conversation.display_id}] #{subject_line}"
  end

  def incoming_mail_subject
    @incoming_mail_subject ||= @conversation.additional_attributes['mail_subject']
  end

  def reply_email
    if should_use_conversation_email_address?
      "#{assignee_name} <reply+#{@conversation.uuid}@#{@account.inbound_email_domain}>"
    else
      @inbox.email_address || @agent&.email
    end
  end

  def from_email_with_name
    if should_use_conversation_email_address?
      "#{assignee_name} from #{@inbox.name} <#{parse_email(@account.support_email)}>"
    else
      "#{assignee_name} from #{@inbox.name} <#{parse_email(inbox_from_email_address)}>"
    end
  end

  def parse_email(email_string)
    Mail::Address.new(email_string).address
  end

  def inbox_from_email_address
    return @inbox.email_address if @inbox.email_address

    @account.support_email
  end

  def custom_message_id
    "<conversation/#{@conversation.uuid}/messages/#{@messages&.last&.id}@#{@account.inbound_email_domain}>"
  end

  def in_reply_to_email
    conversation_reply_email_id || "<account/#{@account.id}/conversation/#{@conversation.uuid}@#{@account.inbound_email_domain}>"
  end

  def conversation_reply_email_id
    content_attributes = @conversation.messages.incoming.last&.content_attributes

    if content_attributes && content_attributes['email'] && content_attributes['email']['message_id']
      return "<#{content_attributes['email']['message_id']}>"
    end

    nil
  end

  def inbound_email_enabled?
    @inbound_email_enabled ||= @account.feature_enabled?('inbound_emails') && @account.inbound_email_domain
                                                                                      .present? && @account.support_email.present?
  end

  def choose_layout
    return false if action_name == 'reply_without_summary'

    'mailer/base'
  end
end
