ROOT = '/etc/openclash'
SETTINGS = '/etc/config/openclash'
LOCK = '/tmp/lock/openclash_backup.lock'
REBUILT = %w[.oix_age_key* ..oix_age_key* .oix_device_id* ..oix_device_id* .managed-device-v2* ..managed-device-v2.tmp-* proxy_provider/oixCloud proxy_provider/.oixCloud.tmp-* .openclash-restore.*]

def temporary(*args)
  path = IO.popen(['mktemp', *args], &:read).chomp
  raise 'Cannot create backup workspace' unless $?.success? && !path.empty?
  path
end

def command(*args)
  raise "#{args.first} failed" unless system(*args)
end

def exists?(path)
  File.symlink?(path) || File.exist?(path)
end

def directory?(path)
  !File.symlink?(path) && File.directory?(path)
end

def install(source, target, previous, changes)
  if directory?(target)
    raise IOError, "Backup entry conflicts with a directory" unless directory?(source)
    Dir.children(source).each { |name| install(File.join(source, name), File.join(target, name), previous, changes) }
    return
  end
  saved = nil
  if exists?(target)
    saved = File.join(previous, changes.size.to_s)
    File.rename(target, saved)
  end
  changes << [target, saved]
  File.rename(source, target)
end

def restore(archive, exclude, stage)
  has_settings = false
  IO.popen(['tar', 'tzf', archive]) do |tar|
    tar.each_line do |line|
      name = line.chomp
      raise 'Invalid backup path' if name.start_with?('/') || name.split('/').include?('..')
      has_settings ||= name == './openclash'
    end
  end
  raise 'Incomplete backup' unless $?.success? && has_settings
  files = File.join(stage, 'files')
  previous = File.join(stage, 'previous')
  Dir.mkdir(files)
  Dir.mkdir(previous)
  command('tar', '-C', files, '-X', exclude, '-xzf', archive)
  settings = File.join(files, 'openclash')
  raise 'Invalid settings file' unless File.lstat(settings).file?
  pending = temporary('/etc/config/.openclash.XXXXXX')
  changes = []
  begin
    File.open(pending, 'wb') { |out| IO.copy_stream(settings, out) }
    Dir.children(files).each do |name|
      install(File.join(files, name), File.join(ROOT, name), previous, changes) unless name == 'openclash'
    end
    File.rename(pending, SETTINGS)
  rescue SystemCallError, IOError, SignalException
    changes.reverse_each.with_index do |(target, saved), index|
      File.rename(target, File.join(stage, "reverted-#{index}")) if exists?(target)
      File.rename(saved, target) if saved
    end
    raise
  ensure
    File.unlink(pending) if File.exist?(pending)
  end
end

# BusyBox tar accepts one working directory. Append its files after the settings member
# by omitting only the first tar stream's end records, then gzip the combined archive.
def write_settings_member(stage, output)
  settings = File.join(stage, 'openclash')
  File.open(settings, 'wb', 0600) { |out| IO.copy_stream(SETTINGS, out) }
  archive = File.join(stage, 'settings.tar')
  command('tar', '-C', stage, '-cf', archive, './openclash')
  File.open(archive, 'rb') do |tar|
    loop do
      header = tar.read(512)
      raise IOError, 'Incomplete settings archive' unless header && header.bytesize == 512
      break if header == "\0" * 512
      output.write(header)
      size = header.byteslice(124, 12).oct
      padded = (size + 511) / 512 * 512
      raise IOError, 'Incomplete settings member' unless IO.copy_stream(tar, output, padded) == padded
    end
  end
end

def create(target, exclude, stage)
  if target == './proxy_provider'
    command('tar', '-C', ROOT, '-X', exclude, '-czf', '-', target)
    return
  end
  raise 'Invalid backup target' unless target == '.'
  File.open(exclude, 'a') { |out| out.puts('./openclash') }
  IO.popen(['gzip', '-c'], 'wb') do |compressed|
    write_settings_member(stage, compressed)
    IO.popen(['tar', '-C', ROOT, '-X', exclude, '-cf', '-', '.'], 'rb') do |files|
      IO.copy_stream(files, compressed)
    end
    raise 'Cannot read backup files' unless $?.success?
  end
  raise 'Cannot compress backup' unless $?.success?
end

action, target, extra = ARGV
File.open(LOCK, 'a', 0600) do |lock|
  restoring = action == 'restore'
  raise 'Cannot lock backup' unless lock.flock(restoring ? File::LOCK_EX : File::LOCK_SH)
  stage = temporary('-d', restoring ? "#{ROOT}/.openclash-restore.XXXXXX" : '/tmp/openclash-backup.XXXXXX')
  exclude = File.join(stage, 'exclude')
  begin
    patterns = REBUILT + (extra ? [extra] : [])
    File.write(exclude, patterns.flat_map { |name| [name, "./#{name}"] }.join("\n") + "\n")
    if restoring
      restore(target, exclude, stage)
    elsif action == 'create'
      create(target, exclude, stage)
    else
      raise 'Invalid backup operation'
    end
  ensure
    system('rm', '-rf', stage) unless restoring && $! && Dir.glob("#{stage}/previous/*").any?
  end
end
