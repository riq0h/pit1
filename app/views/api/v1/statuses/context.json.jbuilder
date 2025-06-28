# frozen_string_literal: true

json.ancestors @ancestors do |status|
  json.partial! 'api/v1/statuses/status', status: status
end

json.descendants @descendants do |status|
  json.partial! 'api/v1/statuses/status', status: status
end
