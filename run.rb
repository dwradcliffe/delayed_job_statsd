require 'pg'
require 'statsd-instrument'
require 'time'

def get_staleness(results)
  return 0 if results.count == 0
  earliest_job = results[0]
  (Time.now.utc - Time.parse(earliest_job["created_at"] + " UTC")).round
end

conn = PG.connect(dbname: ENV.fetch('PG_DATABASE'), host: ENV.fetch('PG_HOST'), user: ENV.fetch('PG_USER'), password: ENV.fetch('PG_PASSWORD'))

tags = ["env:#{ENV.fetch("ENV", "dev")}"]

while true
  # get total jobs
  results = conn.exec("SELECT COUNT(*) AS count FROM delayed_jobs;")
  total_jobs = results[0]["count"]
  StatsD.gauge("delayed_job.total", total_jobs, tags: tags)

  # get failed jobs
  results = conn.exec("SELECT COUNT(*) AS count FROM delayed_jobs WHERE failed_at IS NOT NULL;")
  failed_jobs = results[0]["count"]
  StatsD.gauge("delayed_job.failed", failed_jobs, tags: tags)

  # get staleness
  results = conn.exec("SELECT created_at FROM delayed_jobs WHERE attempts = 0 AND locked_by IS NULL ORDER BY created_at LIMIT 1;")
  StatsD.gauge("delayed_job.staleness", get_staleness(results), tags: tags)

  # get per priority stats
  priorities = conn.exec("SELECT DISTINCT priority FROM delayed_jobs;").values.flatten
  priorities.each do |priority|
    tags_with_priority = tags + ["priority:#{priority}"]

    # get total jobs
    results = conn.exec("SELECT COUNT(*) AS count FROM delayed_jobs WHERE priority = #{priority};")
    total_jobs = results[0]["count"]
    StatsD.gauge("delayed_job.by_priority.total", total_jobs, tags: tags_with_priority)

    # get failed jobs
    results = conn.exec("SELECT COUNT(*) AS count FROM delayed_jobs WHERE failed_at IS NOT NULL AND priority = #{priority};")
    failed_jobs = results[0]["count"]
    StatsD.gauge("delayed_job.by_priority.failed", failed_jobs, tags: tags_with_priority)

    # get staleness
    results = conn.exec("SELECT created_at FROM delayed_jobs WHERE priority = #{priority} AND attempts = 0 AND locked_by IS NULL ORDER BY created_at LIMIT 1;")
    StatsD.gauge("delayed_job.by_priority.staleness", get_staleness(results), tags: tags_with_priority)
  end

  sleep 15
end

conn.close
