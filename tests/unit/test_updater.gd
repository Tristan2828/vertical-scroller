extends GutTest
## Version checks against GitHub releases and the exe swap the updater does.
## (From Medieval Survival.)

const SAMPLE_RELEASE: String = """{
	"tag_name": "v0.15.0",
	"html_url": "https://github.com/Tristan2828/vertical-scroller/releases/tag/v0.15.0",
	"draft": false, "prerelease": false,
	"assets": [
		{"name": "notes.txt", "browser_download_url": "https://github.com/Tristan2828/vertical-scroller/releases/download/v0.15.0/notes.txt", "size": 5},
		{"name": "VerticalScroller-0.15.0-windows.zip", "browser_download_url": "https://github.com/Tristan2828/vertical-scroller/releases/download/v0.15.0/VerticalScroller-0.15.0-windows.zip", "size": 39000000}
	]
}"""

const WORK_DIR: String = "user://test_updater"


func after_each() -> void:
	var dir := DirAccess.open(WORK_DIR)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)


func test_versions_compare_numerically() -> void:
	assert_eq(ReleaseInfo.compare_versions("0.15.0", "0.14.0"), 1)
	assert_eq(ReleaseInfo.compare_versions("0.9.0", "0.10.0"), -1, "not alphabetical")
	assert_eq(ReleaseInfo.compare_versions("v0.14.0", "0.14"), 0)
	assert_eq(ReleaseInfo.compare_versions("1.0.0", "0.99.9"), 1)


func test_parse_finds_the_windows_zip() -> void:
	var info := ReleaseInfo.parse(SAMPLE_RELEASE)
	assert_not_null(info)
	assert_eq(info.version, "0.15.0")
	assert_string_ends_with(info.zip_url, "VerticalScroller-0.15.0-windows.zip")
	assert_eq(info.zip_size, 39000000)
	assert_string_contains(info.page_url, "releases/tag/v0.15.0")


func test_parse_rejects_junk_drafts_and_untrusted_links() -> void:
	assert_null(ReleaseInfo.parse("not json"))
	assert_null(ReleaseInfo.parse("{}"))
	assert_null(ReleaseInfo.parse('{"tag_name": "v9.0.0", "draft": true}'))
	var elsewhere := ReleaseInfo.parse(SAMPLE_RELEASE.replace("https://github.com/Tristan2828/vertical-scroller/releases/download/v0.15.0/VerticalScroller", "https://evil.example/VerticalScroller"))
	assert_eq(elsewhere.zip_url, "", "only downloads from this repo on GitHub")


func test_install_swaps_the_exe_and_keeps_the_old_one() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	var exe := ProjectSettings.globalize_path(WORK_DIR.path_join("VerticalScroller.exe"))
	var zip_path := ProjectSettings.globalize_path(WORK_DIR.path_join("latest.zip"))
	var old_file := FileAccess.open(exe, FileAccess.WRITE)
	old_file.store_string("old game")
	old_file.close()
	var new_bytes := PackedByteArray()
	new_bytes.resize(1_500_000)
	new_bytes.fill(7)
	var packer := ZIPPacker.new()
	packer.open(zip_path)
	packer.start_file("README.txt")
	packer.write_file("hi".to_utf8_buffer())
	packer.close_file()
	packer.start_file("VerticalScroller.exe")
	packer.write_file(new_bytes)
	packer.close_file()
	packer.close()
	assert_eq(Updater._install(zip_path, exe), "")
	assert_eq(FileAccess.get_file_as_bytes(exe).size(), new_bytes.size(), "new exe in place")
	assert_eq(FileAccess.get_file_as_string(exe + Updater.OLD_SUFFIX), "old game", "old exe kept aside")


func test_install_refuses_a_zip_without_the_game() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	var exe := ProjectSettings.globalize_path(WORK_DIR.path_join("VerticalScroller.exe"))
	var zip_path := ProjectSettings.globalize_path(WORK_DIR.path_join("bad.zip"))
	var old_file := FileAccess.open(exe, FileAccess.WRITE)
	old_file.store_string("old game")
	old_file.close()
	var packer := ZIPPacker.new()
	packer.open(zip_path)
	packer.start_file("README.txt")
	packer.write_file("hi".to_utf8_buffer())
	packer.close_file()
	packer.close()
	assert_ne(Updater._install(zip_path, exe), "")
	assert_eq(FileAccess.get_file_as_string(exe), "old game", "nothing touched")


func test_updater_stays_off_in_tests_and_the_editor() -> void:
	assert_false(Updater.can_run())


## (Medieval Survival playtest 8) When GitHub's API refuses, the check reads the release page's
## redirect instead and guesses the zip's name the way release.ps1 names it.
func test_release_from_the_tag_page_link() -> void:
	var info := ReleaseInfo.from_tag_url("https://github.com/Tristan2828/vertical-scroller/releases/tag/v0.25.0")
	assert_eq(info.version, "0.25.0")
	assert_eq(info.zip_url, "https://github.com/Tristan2828/vertical-scroller/releases/download/v0.25.0/VerticalScroller-0.25.0-windows.zip")
	assert_null(ReleaseInfo.from_tag_url("https://evil.example/Tristan2828/vertical-scroller/releases/tag/v9.0.0"))
	assert_null(ReleaseInfo.from_tag_url("https://github.com/Tristan2828/vertical-scroller/releases"))


func test_install_problem_spots_an_exe_run_from_the_zip() -> void:
	assert_string_contains(Updater.install_problem(
		"C:\\Users\\Ana\\AppData\\Local\\Temp\\Temp1_VerticalScroller-0.1.0-windows.zip\\VerticalScroller.exe"), "zip")
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	assert_eq(Updater.install_problem(ProjectSettings.globalize_path(WORK_DIR.path_join("VerticalScroller.exe"))), "",
		"a normal, writable folder is fine")


func test_only_this_repo_is_trusted() -> void:
	assert_true(ReleaseInfo.is_trusted("https://github.com/Tristan2828/vertical-scroller/releases/download/v1/x.zip"))
	assert_false(ReleaseInfo.is_trusted("https://github.com/someone-else/vertical-scroller/releases/download/v1/x.zip"))
	assert_false(ReleaseInfo.is_trusted("https://github.com/Tristan2828/vertical-scroller-evil/releases/download/v1/x.zip"))


## build.ps1 names the zip VerticalScroller-<version>-windows.zip with VerticalScroller.exe
## inside; the updater looks for exactly those.
func test_names_match_what_build_ps1_makes() -> void:
	var build := FileAccess.get_file_as_string("res://tools/build.ps1")
	assert_string_contains(build, "VerticalScroller.exe")
	assert_string_contains(build, "VerticalScroller-$version-windows.zip")
	assert_true(Updater.GAME_EXE_NAMES.has("verticalscroller.exe"))
	assert_eq(ReleaseInfo.ZIP_PREFIX, "VerticalScroller-")
