# frozen_string_literal: true

namespace :scheduled_statuses do
  desc 'Process due scheduled statuses'
  task process: :environment do
    puts "Processing scheduled statuses..."
    
    processed_count = 0
    failed_count = 0
    
    ScheduledStatus.due.find_each do |scheduled_status|
      begin
        status = scheduled_status.publish!
        puts "Published scheduled status #{scheduled_status.id} as status #{status.id}"
        processed_count += 1
      rescue StandardError => e
        puts "Failed to publish scheduled status #{scheduled_status.id}: #{e.message}"
        failed_count += 1
      end
    end
    
    puts "Processed #{processed_count} scheduled statuses"
    puts "Failed #{failed_count} scheduled statuses" if failed_count > 0
  end
end