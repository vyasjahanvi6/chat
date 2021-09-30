redis = Rails.env.test? ? MockRedis.new : Redis.new(Redis::Config.app)

# Alfred
# Add here as you use it for more features
# Used for Round Robin, Conversation Emails & Online Presence
$alfred = Redis::Namespace.new('alfred', redis: redis, warning: true)

# Velma : Determined protector
# used in rack attack
$velma =  Redis::Namespace.new('velma', redis: redis, warning: true)
