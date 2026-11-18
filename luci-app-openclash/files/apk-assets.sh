# apk can continue extracting after a failed package hook.
openclash_apk_assets() (
	umask 077
	mode=$1
	present() { [ -e "$1" ] || [ -L "$1" ]; }
	# BusyBox mv may copy an entire directory when a merged overlay rejects rename.
	rename_tree() {
		[ ! -e "$2" ] && [ ! -L "$2" ] && command -v ruby >/dev/null 2>&1 &&
			ruby -e 'File.rename(ARGV[0], ARGV[1])' "$1" "$2" 2>/dev/null
	}
	clone_tree() {
		if [ "$mode:$parent" = hold:/tmp ] || { command -v ruby >/dev/null 2>&1 &&
				ruby -e 'exit(File.lstat(ARGV[0]).dev == File.stat(File.dirname(ARGV[1])).dev ? 1 : 0)' "$1" "$2"; }; then
			cp -a "$1" "$2"
		else
			cp -al "$1" "$2"
		fi
	}
	mount_topology() {
		rows=$(awk -v path="$live" '$5=="/" || $5==path || index(path,$5"/")==1 || index($5,path"/")==1 {print $1,$3,$4,$5}' /proc/self/mountinfo) || return 1
		if command -v ruby >/dev/null 2>&1 && printf '%s\n' "$rows" | grep -qv ' /$'; then
			restore_mount_files --topology "$live"
			return $?
		fi
		cat /proc/sys/kernel/random/boot_id && printf '%s\n' "$rows" | awk '$4!="/" {$0=$0 " unverified"} {print}'
	}
	same_topology() {
		current=$(mount_topology) && [ -s "$1" ] && ! grep -q ' unverified$' "$1" && [ "$current" = "$(cat "$1")" ]
	}
	restore_mount_files() {
		ruby - "$@" <<'RUBY'
original, live, topology, archive_prefix = ARGV
ChangedMount = Class.new(StandardError)
FileConflict = Class.new(StandardError)
Conflicts = [FileConflict, Errno::ELOOP, Errno::EISDIR, Errno::ENOTDIR, Errno::EBUSY, Errno::EROFS].freeze
def current_topology(live)
  mounts = File.readlines("/proc/self/mountinfo").filter_map do |row|
    id, _, device, root, path = row.split(" ", 6)
    next unless path == "/" || path == live || live.start_with?(path + "/") || path.start_with?(live + "/")
    entry = [id, device, root, path].join(" ")
    next entry if path == "/"
    mount = path.gsub(/\\([0-7]{3})/) { Regexp.last_match(1).to_i(8).chr }
    entry += " " + row.split(" - ", 2).last.split(" ", 2).first
    begin
      born = File.birthtime(mount)
      # A zero or whole-second birth time cannot distinguish rapid remounts.
      if born.to_i <= 0 || born.nsec.zero?
        "#{entry} unverified"
      else
        format("%s %d %d.%09d", entry, File.stat(mount).ino, born.to_i, born.nsec)
      end
    rescue SystemCallError, NotImplementedError
      "#{entry} unverified"
    end
  end
  [File.read("/proc/sys/kernel/random/boot_id").strip, *mounts]
end
if original == "--topology"
  puts current_topology(live)
  exit
end
expected = File.readlines(topology, chomp: true)
check_mounts = lambda do
  raise ChangedMount, "original mount points could not be verified under #{live}" unless current_topology(live) == expected && expected.none? { |row| row.end_with?(" unverified") }
end
def same_entry?(source, dest, stat)
  other = File.lstat(dest)
  return false unless [stat.mode, stat.uid, stat.gid, stat.size, stat.mtime.to_i] == [other.mode, other.uid, other.gid, other.size, other.mtime.to_i]
  return File.readlink(source) == File.readlink(dest) if stat.symlink?
  File.open(dest, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |current|
    File.open(source, "rb") do |saved|
      loop do
        chunk = saved.read(65536)
        return false unless chunk == current.read(65536)
        return true unless chunk
      end
    end
  end
rescue Errno::ENOENT
  false
end
def with_saved_link(live, entry, check_mounts)
  parts, name, device, inode = entry
  flags = File::RDONLY | File::NOFOLLOW | File::NONBLOCK
  dir = File.open(live, flags)
  begin
    parts.each do |part|
      child = File.open("/proc/self/fd/#{dir.fileno}/#{part}", flags)
      dir.close
      dir = child
    end
    check_mounts.call
    path = "/proc/self/fd/#{dir.fileno}/#{name}"
    stat = File.lstat(path)
    raise FileConflict, "hard link changed at #{name}" unless stat.dev == device && stat.ino == inode
    yield path, stat
  ensure
    dir.close
  end
end
def copy_asset(source, dest, stat)
  if stat.symlink?
    File.symlink(File.readlink(source), dest)
    File.lchown(stat.uid, stat.gid, dest)
    File.lutime(stat.atime, stat.mtime, dest)
  elsif stat.file?
    File.open(dest, File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
      File.open(source, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) { |input| IO.copy_stream(input, file) }
      file.chown(stat.uid, stat.gid)
      file.chmod(stat.mode & 07777)
    end
    File.utime(stat.atime, stat.mtime, dest)
  else
    raise FileConflict, "unsupported file type at #{source}"
  end
end
archive = nil
archive_dir = lambda do |parts|
  raise FileConflict, "no writable private directory for conflicting assets" if archive_prefix == "-"
  unless archive
    parent = "#{archive_prefix}.#{Random.urandom(12).unpack1('H*')}"
    Dir.mkdir(parent, 0700)
    archive = File.join(parent, "tree")
    Dir.mkdir(archive, 0700)
    warn "OpenClash: retained conflicting assets from the interrupted transaction at #{archive}"
  end
  parts.reduce(archive) do |parent, part|
    path = File.join(parent, part)
    Dir.mkdir(path, 0700) unless File.directory?(path)
    path
  end
end
links, archived_links = {}, {}
restore_file = lambda do |source, dest, stat, reference, previous, parts|
  raise FileConflict, "unsupported file type at #{source}" unless stat.file? || stat.symlink?
  next if same_entry?(source, dest, stat) && (!reference || File.identical?(reference, dest))
  staging = File.join(File.dirname(dest), ".openclash-restore.#{Random.urandom(12).unpack1('H*')}")
  Dir.mkdir(staging, 0700)
  staged = File.join(staging, "new")
  begin
    if reference
      File.link(reference, staged)
      linked = File.lstat(staged)
      raise FileConflict, "hard link changed at #{source}" unless linked.dev == previous.dev && linked.ino == previous.ino
    else
      copy_asset(source, staged, stat)
    end
    if archive_prefix && (File.symlink?(dest) || File.exist?(dest))
      current = File.lstat(dest)
      raise FileConflict, "directory conflict at #{source}" if current.directory?
      target = File.join(archive_dir.call(parts), File.basename(dest))
      key = current.file? ? [current.dev, current.ino] : nil
      saved = archived_links[key]
      if saved && same_entry?(dest, saved, current)
        File.link(saved, target)
      else
        begin
          copy_asset(dest, target, current)
        rescue SystemCallError, IOError
          File.unlink(target) if File.exist?(target) || File.symlink?(target)
          raise
        end
        archived_links[key] = target if key && current.nlink > 1
      end
    end
    File.rename(staged, dest)
  ensure
    File.unlink(staged) if File.exist?(staged) || File.symlink?(staged)
    Dir.rmdir(staging)
  end
end
manual = false
restore = lambda do |source, dest, parts|
  check_mounts.call
  Dir.mkdir(dest, 0700) unless File.exist?(dest) || File.symlink?(dest)
  File.open(dest, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |dir|
    raise FileConflict, "directory type conflict at #{dest}" unless dir.stat.directory?
    check_mounts.call
    base = "/proc/self/fd/#{dir.fileno}"
    initial = dir.stat
    Dir.each_child(source) do |name|
      from, to = File.join(source, name), File.join(base, name)
      stat = File.lstat(from)
      begin
        if stat.directory?
          restore.call(from, to, parts + [name])
        else
          key = stat.file? && stat.nlink > 1 ? [stat.dev, stat.ino, dir.stat.dev] : nil
          if key && links.key?(key)
            with_saved_link(live, links.fetch(key), check_mounts) do |reference, previous|
              restore_file.call(from, to, stat, reference, previous, parts)
            end
          else
            restore_file.call(from, to, stat, nil, nil, parts)
            if key
              copied = File.lstat(to)
              links[key] = [parts, name, copied.dev, copied.ino]
            end
          end
        end
      rescue *Conflicts => error
        warn "OpenClash: retained mounted asset #{from}: #{error.message}"
        manual = true
      end
    end
    saved, current = File.lstat(source), dir.stat
    if archive_prefix && ([saved.uid, saved.gid, saved.mode] != [initial.uid, initial.gid, initial.mode] || (archive && File.directory?(File.join(archive, *parts))))
      target = archive_dir.call(parts)
      File.chown(initial.uid, initial.gid, target)
      File.chmod(initial.mode & 07777, target)
      File.utime(initial.atime, initial.mtime, target)
    end
    dir.chown(saved.uid, saved.gid) if saved.uid != current.uid || saved.gid != current.gid
    dir.chmod(saved.mode & 07777) if saved.mode != dir.stat.mode
    File.utime(saved.atime, saved.mtime, base) if saved.mtime.to_i != dir.stat.mtime.to_i
  end
end
begin
  restore.call(original, live, [])
  exit 2 if manual
rescue ChangedMount, *Conflicts => error
  warn "OpenClash: mounted asset conflict: #{error.message}"
  exit 2
rescue SystemCallError, RuntimeError => error
  warn "OpenClash: mounted asset restore failed: #{error.message}"
  exit 1
end
RUBY
	}
	hold_tree() {
		present "$live" || return 0
		mkdir "$slot" || return 1
		if ! echo "$token" >"$slot/owner"; then
			rm -f "$slot/owner"
			rmdir "$slot"
			return 1
		fi
		mount_topology >"$slot/mounts" || return 1
		if [ "$mounted" = 1 ]; then
			cp -a "$live" "$slot/partial" || return 1
		else
			if [ "$parent" != /tmp ] && rename_tree "$live" "$slot/original"; then return 0; fi
			clone_tree "$live" "$slot/partial" || return 1
		fi
		current=$(mount_topology) && [ "$current" = "$(cat "$slot/mounts")" ] || return 1
		mv -T "$slot/partial" "$slot/original" || return 1
		# A package must not follow a customized top-level symlink.
		[ ! -L "$live" ] || rm "$live"
	}
	restore_tree() {
		present "$slot" || return 0
		[ -d "$slot" ] && [ ! -L "$slot" ] || return 1
		if ! present "$slot/original"; then
			if present "$slot/partial"; then
				if ! recovered=$(mktemp -d "$vault/recovered-$name.XXXXXX") || ! mv -T "$slot/partial" "$recovered/tree"; then
					[ -z "$recovered" ] || rmdir "$recovered"
					echo "OpenClash: incomplete backup for $live retained at $slot/partial; review it for missing files" >&2
					return 0
				fi
				echo "OpenClash: incomplete backup for $live retained at $recovered/tree; review it for missing files" >&2
			fi
			rm -f "$slot/owner" "$slot/mounts" && rmdir "$slot"
			return $?
		fi
		if same_topology "$slot/mounts"; then same_mount=1; else same_mount=0; fi
		if [ "$mounted" = 1 ] || [ "$same_mount" = 0 ]; then
			if [ "$same_mount" = 1 ] && command -v ruby >/dev/null 2>&1; then
				set -- "$slot/original" "$live" "$slot/mounts"
				if [ -z "$token" ] || [ "$(cat "$slot/owner" 2>/dev/null)" != "$token" ]; then
					set -- "$@" "$vault/recovered-$name"
				fi
				result=0
				restore_mount_files "$@" || result=$?
				case "$result" in
				0) rm -rf "$slot/original" && rm -f "$slot/owner" "$slot/mounts" && rmdir "$slot"; return $? ;;
				2) ;;
				*) return 1 ;;
				esac
			fi
			recovered=$(mktemp -d "$vault/recovered-$name.XXXXXX") || return 1
			mv -T "$slot/original" "$recovered/tree" || return 1
			echo "OpenClash: restore $live from $recovered/tree after checking the mount identity or file conflict" >&2
			rm -f "$slot/owner" "$slot/mounts" && rmdir "$slot"
			return $?
		fi
		displaced=
		if present "$live"; then
			displaced=$(mktemp -d "$vault/recovered-$name.XXXXXX") || return 1
			if ! rename_tree "$live" "$displaced/tree"; then
				clone_tree "$live" "$displaced/tree" && rm -rf "$live" || return 1
			fi
		fi
		if ! rename_tree "$slot/original" "$live"; then
			clone_tree "$slot/original" "$live" && rm -rf "$slot/original" || return 1
		fi
		if [ -n "$displaced" ]; then
			if [ -n "$token" ] && [ "$(cat "$slot/owner" 2>/dev/null)" = "$token" ]; then
				rm -rf "$displaced" || return 1
			else
				echo "OpenClash: retained assets from the interrupted transaction at $displaced/tree" >&2
			fi
		fi
		rm -f "$slot/owner" "$slot/mounts" && rmdir "$slot"
	}
	private_dir() {
		[ ! -L "$1" ] && LC_ALL=C ls -nd "$1" 2>/dev/null | awk '$1=="drwx------" && $3=="0" {ok=1} END {exit !ok}'
	}
	prepare_vault() {
		vault=$parent/.openclash-apk-assets
		marker=.owner
		[ "$parent" != /etc ] || marker=
		if ! present "$vault" && [ "$mode" = restore ]; then return 1; fi
		[ "$(readlink -f "$parent")" = "$parent" ] && LC_ALL=C ls -nd "$parent" | awk -v dir="$parent" '
			$3==0 && substr($1,1,1)=="d" && ((substr($1,6,1)!="w" && substr($1,9,1)!="w") ||
				(dir=="/tmp" && substr($1,10,1)=="t")) {ok=1} END {exit !ok}' || return 1
		if ! present "$vault"; then
			mkdir -m 700 "$vault" || return 1
			if ! mkdir "$vault/v1"; then rmdir "$vault"; return 1; fi
			if [ -n "$marker" ] && ! echo openclash-apk-assets >"$vault/v1/$marker"; then
				rm -f "$vault/v1/$marker"; rmdir "$vault/v1" "$vault"; return 1
			fi
			return 0
		fi
		if [ -z "$marker" ] && [ "$mode" != restore ] && private_dir "$vault" && [ -z "$(ls -A "$vault")" ]; then
			mkdir "$vault/v1" || return 1
			return 0
		fi
		known=0
		if [ ! -L "$vault" ] && [ ! -L "$vault/v1" ] && [ -d "$vault/v1" ]; then
			if [ -z "$marker" ] || { [ ! -L "$vault/v1/$marker" ] && LC_ALL=C ls -nd "$vault/v1/$marker" 2>/dev/null |
				awk '$3==0 && substr($1,1,1)=="-" && $5==length("openclash-apk-assets")+1 {ok=1} END {exit !ok}'; }; then
				if private_dir "$vault" && private_dir "$vault/v1"; then
					if [ -z "$marker" ] || echo openclash-apk-assets | cmp -s - "$vault/v1/$marker"; then return 0; fi
				else
					known=1
				fi
			fi
		fi
		echo "OpenClash: asset recovery path $vault is occupied, check its owner, permissions and contents" >&2
		[ "$known" != 1 ] || return 2
		return 1
	}
	clean_vault() {
		if [ "$(ls -A "$vault/v1")" = "$marker" ] && [ "$(ls -A "$vault")" = v1 ]; then
			[ -z "$marker" ] || rm -f "$vault/v1/$marker"
			rmdir "$vault/v1" && rmdir "$vault" || :
		fi
	}
	retain_legacy() {
		awk -v path="$legacy" '$5==path || index($5,path "/")==1 {exit 1}' /proc/self/mountinfo || return 1
		for parent in /etc /root /usr/share /tmp; do
			prepare_vault || continue
			recovered=$(mktemp -d "$vault/recovered-legacy-$asset.XXXXXX") || continue
			if rename_tree "$legacy" "$recovered/tree"; then
				echo "OpenClash: retained the earlier backup from $legacy at $recovered/tree" >&2
				[ "$parent" != /tmp ] || echo "OpenClash: recover this temporary backup before rebooting" >&2
				return 0
			fi
			rmdir "$recovered"
			clean_vault
		done
		echo "OpenClash: could not retain the earlier backup at $legacy, keeping the package backup at $backup" >&2
		return 1
	}
	restore_conflicts() {
		for parent in /etc /root /usr/share /tmp; do
			prepare_vault && [ -w "$vault" ] || continue
			rc=0
			restore_mount_files "$1" "$2" "$3" "$vault/recovered-$4" || rc=$?
			clean_vault
			case "$rc" in 0|2) return "$rc" ;; esac
		done
		restore_mount_files "$1" "$2" "$3" "-"
	}
	token=$(awk -v boot="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)" 'NF >= 22 && boot != "" {print boot, $1, $22}' "/proc/$PPID/stat" 2>/dev/null)
	case "$mode" in
	backup|restore-backup)
		backup=$2
		mounts=$backup/apk-mounts
		preserve=0
		if [ "$mode" = backup ]; then
			mkdir "$mounts" || exit 1
		elif present "$mounts"; then
			if ! private_dir "$backup" || ! private_dir "$mounts" || [ ! -f "$backup/ready" ]; then
				echo "OpenClash: incomplete or unsafe package backup at $backup, leaving it untouched" >&2
				exit 1
			fi
			if [ "${3:-}" = retry ] || { [ -f "$mounts/restored-by" ] && { [ -z "$token" ] || [ "$(cat "$mounts/restored-by")" != "$token" ]; }; }; then
				preserve=1
			fi
			echo pending >"$mounts/restored-by" || exit 1
		fi
		for pass in check copy; do
			for asset in openclash_ui pac; do
				case "$asset" in
				openclash_ui) live=/usr/share/openclash/ui ;;
				pac) live=/www/luci-static/resources/openclash/pac ;;
				esac
				saved=$backup/$asset
				topology=$mounts/$asset
				if [ "$mode" = backup ]; then
					if [ "$pass" = check ]; then
						mount_topology >"$topology" || exit 1
					else
						if [ -d "$live" ] || [ -L "$live" ]; then cp -a "$live" "$saved" || exit 1; fi
						current=$(mount_topology) && [ "$current" = "$(cat "$topology")" ] || exit 1
					fi
					continue
				fi
				legacy=/tmp/$asset
				[ -f /tmp/openclash.bak ] || legacy=
				present "$saved" || { [ -n "$legacy" ] && present "$legacy"; } || continue
				mounted=0
				awk -v path="$live" '$5==path || index($5,path "/")==1 || ($5!="/" && index(path,$5 "/")==1) ||
					($5=="/" && $6 ~ /(^|,)ro(,|$)/) {exit 1}' /proc/self/mountinfo || mounted=1
				if [ -d "$mounts" ]; then
					same_topology "$topology" || {
						echo "OpenClash: mount points changed or could not be verified for $live, retaining the package backup at $backup" >&2
						if [ -n "$legacy" ] && present "$legacy"; then echo "OpenClash: retaining the earlier backup at $legacy" >&2; fi
						exit 1
					}
				fi
				if [ "$mounted" = 1 ] && [ ! -d "$mounts" ]; then
					echo "OpenClash: backup for mounted $live has no verified source mount, retaining the package backup at $backup" >&2
					if [ -n "$legacy" ] && present "$legacy"; then echo "OpenClash: retaining the earlier backup at $legacy" >&2; fi
					exit 1
				fi
				[ "$pass" = copy ] || continue
				if [ "$mounted" = 1 ] && [ -n "$legacy" ] && present "$legacy"; then
					retain_legacy || exit 1
					legacy=
				fi
				for tree in "$legacy" "$saved"; do
					[ -n "$tree" ] && present "$tree" || continue
					if [ "$(readlink -f "${live%/*}")" != "${live%/*}" ]; then exit 1; fi
					if [ -L "$tree" ] || [ -L "$live" ]; then
						[ -L "$tree" ] && [ -L "$live" ] && [ "$(readlink "$tree")" = "$(readlink "$live")" ] || exit 1
					elif [ "$preserve" = 1 ]; then
						restore_conflicts "$tree" "$live" "$topology" "$asset" || {
							echo "OpenClash: could not preserve conflicting edits or fully restore $live, retaining $backup" >&2
							exit 1
						}
					elif [ "$mounted" = 1 ]; then
						restore_mount_files "$tree" "$live" "$topology" || {
							echo "OpenClash: could not fully restore $live, retaining the package backup at $backup" >&2
							exit 1
						}
					else
						cp -af "$tree/." "$live/" || exit 1
					fi
				done
				if [ -d "$mounts" ]; then
					current=$(mount_topology) && [ "$current" = "$(cat "$topology")" ] || exit 1
				fi
			done
		done
		if [ "$mode" = restore-backup ] && [ -d "$mounts" ]; then echo "$token" >"$mounts/restored-by" || exit 1; fi
		exit 0
		;;
	esac
	status=0
	names="ui pac"
	for parent in /etc /root /usr/share /tmp; do
		rc=0
		prepare_vault || rc=$?
		if [ "$rc" != 0 ]; then
			if [ "$rc" = 2 ] && [ "$mode" = restore ]; then status=1; fi
			continue
		fi
		retry=
		for name in $names; do
			case "$name" in
			ui) live=/usr/share/openclash/ui ;;
			pac) live=/www/luci-static/resources/openclash/pac ;;
			esac
			slot=$vault/v1/$name
			if ! present "$live" && [ ! -d "$slot" ]; then continue; fi
			mounted=0
			awk -v path="$live" '$5==path || index($5,path "/")==1 {exit 1}' /proc/self/mountinfo || mounted=1
			if [ "$(readlink -f "${live%/*}")" != "${live%/*}" ] || ! "${mode}_tree"; then
				echo "OpenClash: could not $mode $live, check writable space on its filesystem and retained files in $vault" >&2
				if [ "$mode" = hold ] && ! present "$slot/original"; then retry="$retry $name"; else status=1; fi
			elif [ "$mode" = hold ] && [ "$parent" != /etc ]; then
				echo "OpenClash: preserved $live in $slot/original" >&2
				[ "$parent" != /tmp ] || echo "OpenClash: recover this temporary backup before rebooting" >&2
			fi
		done
		clean_vault
		if [ "$mode" = hold ]; then names=$retry; [ -n "$names" ] || break; fi
	done
	[ "$mode" != hold ] || [ -z "$names" ] || status=1
	exit "$status"
)
