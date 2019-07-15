require "bundler"

Bundler.require

Dotenv.load

def log(str)
  File.open("log.txt", "a") do |f|
    f.puts "#{Time.now.iso8601}: #{str}"
  end
end

def run_test
  begin
    result = {
      monitor_name: ENV['MONITOR_NAME'],
      api_token: ENV['API_TOKEN'],
    }
    test = Speedtest::Test.new(
      download_runs: 1,
        upload_runs: 1,
        ping_runs: 4,
        download_sizes: [750, 1500],
        upload_sizes: [10000, 400000],
        debug: true
     )
    test_results = test.run

    result = result.merge({
      latency: test_results.latency,
      download_rate: test_results.download_rate,
      upload_rate: test_results.upload_rate,
      server: test_results.server
    })
  rescue Exception => e
    result = result.merge({
      error: e.message,
      backtrace: e.backtrace[0..10]
    })
  end

  result
end

def write_test_to_file(test_results)
  filename = Time.now.strftime("result-%Y-%m-%d--%H-%M.json")
  File.open(filename, "w") do |f|
    f.write test_results.to_json
  end
  log("logged to #{filename} - #{test_results.to_json}")
end


def read_test_and_push_to_server
  Dir["*.json"].each do |filename|
    json = File.read(filename)
    begin
      Faraday.post(
        "#{ENV['MONITOR_WEB_URL']}/api/v1/connection_tests",
        json,
        "Content-Type" => "application/json"
      )
      File.unlink(filename)
      log("pushed up #{filename}")
    rescue Exception => e
      log(e.message)
      e.backtrace[0..10].each do |bt|
        log(bt)
      end
    end
  end
end

# do one test
test_results = run_test
write_test_to_file(test_results)
read_test_and_push_to_server


