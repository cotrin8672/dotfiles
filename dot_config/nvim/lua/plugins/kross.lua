return {
	"cotrin8672/kross.nvim",
	lazy = true,
	build = "gradle jar --no-daemon",
	cmd = { "KrossBuild", "KrossWatchStart", "KrossWatchStop" },
	-- Build explicitly until kross retains saves that arrive during a build.
	opts = { plugin_auto_build = false, watch = false },
}
