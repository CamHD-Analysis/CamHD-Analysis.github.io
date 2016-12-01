require 'bundler'
Bundler.require(:default)

# baseurl = "amarburg/site"
port = 4001

serve_args = %w( jekyll server --incremental --verbose )
serve_args << %W( --port #{port}) if port != 4000

desc 'Serve pages as on the webhost'
task :serve do
  sh serve_args.join(' ')
#  sh "jekyll serve -d _site/#{baseurl} -b /#{baseurl} --incremental"
end

desc 'Serve all pages (future and drafts)'
task :serve_all do
  sh (serve_args + %w(--drafts --future)).join(' ')
#  sh "jekyll serve -d _site/#{baseurl} -b /#{baseurl} --incremental --drafts --future"
end

desc 'Manually rebuild the site'
task :rebuild do
  sh "jekyll build --future"
end

desc 'Rebuild website and check with HTMLProofer'
task :check => :rebuild do
  Bundler.require(:test)

  HTMLProofer.check_directory( "./_site", url_swap: { /^\/public-www\// => '/' } ).run
end

desc 'Push website to origin (Github pages)'
task :push do
  sh "git push origin"
end

task :publish => [:check, :push ]
