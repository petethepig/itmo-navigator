task :preview do
  pids = [
    spawn("jekyll serve -w"), # put `auto: true` in your _config.yml
    spawn("scss --watch _assets/main.sass:assets/main.css"),
    spawn("coffee -b -w -o assets -c _assets ")
  ]
 
  trap "INT" do
    Process.kill "INT", *pids
    exit 1
  end
 
  loop do
    sleep 1
  end
end
