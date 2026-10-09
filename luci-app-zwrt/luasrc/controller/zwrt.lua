module("luci.controller.zwrt", package.seeall)

function index()
	entry({"admin", "system", "zwrt"}, cbi("zwrt/general"), _("ZWRT Theme"), 90).dependent = false
end
