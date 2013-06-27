# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2008 Jean Privat <jean@pryen.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ni_nitdoc

import model_utils
import abstract_compiler
import html

class Nitdoc
	private var toolcontext: ToolContext
	private var model: Model
	private var modelbuilder: ModelBuilder
	private var mainmodule: MModule
	private var arguments: Array[String]
	private var destinationdir: nullable String
	private var sharedir: nullable String

	private var opt_dir = new OptionString("Directory where doc is generated", "-d", "--dir")
	private var opt_source = new OptionString("What link for source (%f for filename, %l for first line, %L for last line)", "--source")
	private var opt_sharedir = new OptionString("Directory containing the nitdoc files", "--sharedir")
	private var opt_nodot = new OptionBool("Do not generate graphes with graphiviz", "--no-dot")

	init(toolcontext: ToolContext) do
		# We need a model to collect stufs
		self.toolcontext = toolcontext
		self.arguments = toolcontext.option_context.rest
		toolcontext.option_context.add_option(opt_dir)
		toolcontext.option_context.add_option(opt_source)
		toolcontext.option_context.add_option(opt_sharedir)
		toolcontext.option_context.add_option(opt_nodot)
		process_options

		if arguments.length < 1 then
			toolcontext.option_context.usage
			exit(1)
		end

		model = new Model
		modelbuilder = new ModelBuilder(model, toolcontext)

		# Here we load an process std modules
		var mmodules = modelbuilder.parse_and_build([arguments.first])
		if mmodules.is_empty then return
		modelbuilder.full_propdef_semantic_analysis
		assert mmodules.length == 1
		self.mainmodule = mmodules.first
	end

	private fun process_options do
		if not opt_dir.value is null then
			destinationdir = opt_dir.value
		else
			destinationdir = "nitdoc_directory"
		end
		if not opt_sharedir.value is null then
			sharedir = opt_sharedir.value
		else
			var dir = "NIT_DIR".environ
			if dir.is_empty then
				dir = "{sys.program_name.dirname}/../share/nitdoc"
			else
				dir = "{dir}/share/nitdoc"
			end
			sharedir = dir
			if sharedir is null then
				print "Error: Cannot locate nitdoc share files. Uses --sharedir or envvar NIT_DIR"
				abort
			end
			dir = "{sharedir.to_s}/scripts/js-facilities.js"
			if sharedir is null then
				print "Error: Invalid nitdoc share files. Check --sharedir or envvar NIT_DIR"
				abort
			end
		end
	end

	fun start do
		if arguments.length == 1 then
			# Create destination dir if it's necessary
			if not destinationdir.file_exists then destinationdir.mkdir
			sys.system("cp -r {sharedir.to_s}/* {destinationdir.to_s}/")
			overview
			fullindex
		end
	end

	fun overview do
		var overviewpage = new NitdocOverview.with(modelbuilder.nmodules, self.opt_nodot.value, destinationdir.to_s)
		overviewpage.save("{destinationdir.to_s}/index.html")
	end

	fun fullindex do
		var fullindex = new NitdocFullindex.with(model.mmodules)
		fullindex.save("{destinationdir.to_s}/full-index.html")
	end

end

class NitdocOverview
	super NitdocPage

	var amodules: Array[AModule]

	# Init with Array[AModule] to get all ifnormations about each MModule containt in a program
	# opt_nodot to inform about the graph gen
	# destination: to know where will be saved dot files
	init with(modules: Array[AModule], opt_nodot: Bool, destination: String) do
		self.amodules = modules
		self.opt_nodot = opt_nodot
		self.destinationdir = destination
	end

	redef fun head do
		super
		add("title").text("Overview | Nit Standard Library")
	end

	redef fun header do
		open("header")
		open("nav").add_class("main")
		open("ul")
		add("li").add_class("current").text("Overview")
		open("li")
		add_html("<a href=\"full-index.html\">Full Index</a>")
		close("li")
		open("li").attr("id", "liGitHub")
		open("a").add_class("btn").attr("id", "logGitHub")
		add("img").attr("id", "imgGitHub").attr("src", "resources/icons/github-icon.png")
		close("a")
		open("div").add_class("popover bottom")
		add("div").add_class("arrow").text(" ")
		open("div").add_class("githubTitle")
		add("h3").text("Github Sign In")
		close("div")
		open("div")
		add("label").attr("id", "lbloginGit").text("Username")
		add("input").attr("id", "loginGit").attr("name", "login").attr("type", "text")
		open("label").attr("id", "logginMessage").text("Hello ")
		open("a").attr("id", "githubAccount")
		add("strong").attr("id", "nickName").text(" ")
		close("a")
		close("label")
		close("div")
		open("div")
		add("label").attr("id", "lbpasswordGit").text("Password")
		add("input").attr("id", "passwordGit").attr("name", "password").attr("type", "password")
		open("div").attr("id", "listBranches")
		add("label").attr("id", "lbBranches").text("Branch")
		add("select").add_class("dropdown").attr("id", "dropBranches").attr("name", "dropBranches").attr("tabindex", "1").text(" ")
		close("div")
		close("div")
		open("div")
		add("label").attr("id", "lbrepositoryGit").text("Repository")
		add("input").attr("id", "repositoryGit").attr("name", "repository").attr("type", "text")
		close("div")
		open("div")
		add("label").attr("id", "lbbranchGit").text("Branch")
		add("input").attr("id", "branchGit").attr("name", "branch").attr("type", "text")
		close("div")
		open("div")
		add("a").attr("id", "signIn").text("Sign In")
		close("div")
		close("div")
		close("li")
		close("ul")
		close("nav")
		close("header")
	end

	redef fun body do
		super
		open("div").add_class("page")
		open("div").add_class("content fullpage")
		add("h1").text("Nit Standard Library")
		open("article").add_class("overview")
		add_html("<p>Documentation for the standard library of Nit<br />Version jenkins-component=stdlib-19<br />Date: TODAY</p>")
		close("article")
		open("article").add_class("overview")
		add("h2").text("Modules")
		open("ul")
		add_modules
		close("ul")
		process_generate_dot
		close("article")
		close("div")
		close("div")
		add("footer").text("Nit standard library. Version jenkins-component=stdlib-19.")
	end

	fun add_modules do
		var ls = new List[nullable MModule]
		for amodule in amodules do
			var mmodule = amodule.mmodule.public_owner
			if mmodule != null and not ls.has(mmodule) then
				open("li")
				add("a").attr("href", "{mmodule.name}.html").text("{mmodule.to_s} ")
				add_html(amodule.comment)
				close("li")
				ls.add(mmodule)
			end
		end
	end

	fun process_generate_dot do
		var op = new Buffer
		op.append("digraph dep \{ rankdir=BT; node[shape=none,margin=0,width=0,height=0,fontsize=10]; edge[dir=none,color=gray]; ranksep=0.2; nodesep=0.1;\n")
		for amodule in amodules do
			op.append("\"{amodule.mmodule.name}\"[URL=\"{amodule.mmodule.name}.html\"];\n")
			for mmodule2 in amodule.mmodule.in_importation.direct_greaters do
				op.append("\"{amodule.mmodule.name}\"->\"{mmodule2.name}\";\n")
			end
		end
		op.append("\}\n")
		generate_dot(op.to_s, "dep", "Modules hierarchy")
	end

end

class NitdocFullindex
	super NitdocPage

	var mmodules: Array[MModule]

	init with(mmodules: Array[MModule]) do
		self.mmodules = mmodules
		opt_nodot = false
		destinationdir = ""
	end

	redef fun head do
		super
		add("title").text("Full Index | Nit Standard Library")
	end

	redef fun header do
		open("header")
		open("nav").add_class("main")
		open("ul")
		open("li")
		add_html("<a href=\"index.html\">Overview</a>")
		close("li")
		add("li").add_class("current").text("Full Index")
		open("li").attr("id", "liGitHub")
		open("a").add_class("btn").attr("id", "logGitHub")
		add("img").attr("id", "imgGitHub").attr("src", "resources/icons/github-icon.png")
		close("a")
		open("div").add_class("popover bottom")
		add("div").add_class("arrow").text(" ")
		open("div").add_class("githubTitle")
		add("h3").text("Github Sign In")
		close("div")
		open("div")
		add("label").attr("id", "lbloginGit").text("Username")
		add("input").attr("id", "loginGit").attr("name", "login").attr("type", "text")
		open("label").attr("id", "logginMessage").text("Hello ")
		open("a").attr("id", "githubAccount")
		add("strong").attr("id", "nickName").text(" ")
		close("a")
		close("label")
		close("div")
		open("div")
		add("label").attr("id", "lbpasswordGit").text("Password")
		add("input").attr("id", "passwordGit").attr("name", "password").attr("type", "password")
		open("div").attr("id", "listBranches")
		add("label").attr("id", "lbBranches").text("Branch")
		add("select").add_class("dropdown").attr("id", "dropBranches").attr("name", "dropBranches").attr("tabindex", "1").text(" ")
		close("div")
		close("div")
		open("div")
		add("label").attr("id", "lbrepositoryGit").text("Repository")
		add("input").attr("id", "repositoryGit").attr("name", "repository").attr("type", "text")
		close("div")
		open("div")
		add("label").attr("id", "lbbranchGit").text("Branch")
		add("input").attr("id", "branchGit").attr("name", "branch").attr("type", "text")
		close("div")
		open("div")
		add("a").attr("id", "signIn").text("Sign In")
		close("div")
		close("div")
		close("li")
		close("ul")
		close("nav")
		close("header")
	end

	redef fun body do
		super
		open("div").add_class("page")
		open("div").add_class("content fullpage")
		add("h1").text("Full Index")
		add_content
		close("div")
		close("div")
		add("footer").text("Nit standard library. Version jenkins-component=stdlib-19.")
	end

	fun add_content do
		module_column
	end

	# Add to content modules column
	fun module_column do
		var ls = new List[nullable MModule]
		open("article").add_class("modules filterable")
		add("h2").text("Modules")
		open("ul")
		for mmodule in mmodules do
			if mmodule.public_owner != null and not ls.has(mmodule.public_owner) then
				ls.add(mmodule.public_owner)
				open("li")
				add("a").attr("href", "{mmodule.public_owner.name}.html").text(mmodule.public_owner.name)
				close("li")
			end
		end
		close("ul")
		close("article")
	end

end

class NitdocPage
	super HTMLPage

	var opt_nodot: Bool
	var destinationdir : String

	redef fun head do
		add("meta").attr("charset", "utf-8")
		add("script").attr("type", "text/javascript").attr("src", "scripts/jquery-1.7.1.min.js")
		add("script").attr("type", "text/javascript").attr("src", "quicksearch-list.js")
		add("script").attr("type", "text/javascript").attr("src", "scripts/js-facilities.js")
		add("link").attr("rel", "stylesheet").attr("href", "styles/main.css").attr("type", "text/css").attr("media", "screen")
	end

	redef fun body do header
	fun header do end

	# Generate a clickable graphviz image using a dot content
	fun generate_dot(dot: String, name: String, alt: String) do
		if opt_nodot then return
		var file = new OFStream.open("{self.destinationdir}/{name}.dot")
		file.write(dot)
		file.close
		sys.system("\{ test -f {self.destinationdir}/{name}.png && test -f {self.destinationdir}/{name}.s.dot && diff {self.destinationdir}/{name}.dot {self.destinationdir}/{name}.s.dot >/dev/null 2>&1 ; \} || \{ cp {self.destinationdir}/{name}.dot {self.destinationdir}/{name}.s.dot && dot -Tpng -o{self.destinationdir}/{name}.png -Tcmapx -o{self.destinationdir}/{name}.map {self.destinationdir}/{name}.s.dot ; \}")
		open("article").add_class("graph")
		add("img").attr("src", "{name}.png").attr("usemap", "#{name}").attr("style", "margin:auto").attr("alt", "{alt}")
		close("article")
		var fmap = new IFStream.open("{self.destinationdir}/{name}.map")
		add_html(fmap.read_all)
		fmap.close
	end

end

redef class AModule
	private fun comment: String do
		var ret = ""
		if n_moduledecl is null or n_moduledecl.n_doc is null then ret
		if n_moduledecl.n_doc is null then return ""
		for t in n_moduledecl.n_doc.n_comment do
			ret += "{t.text.replace("# ", "")}"
		end
		return ret
	end

	private fun short_comment: String do
		var ret = ""
		if n_moduledecl != null and n_moduledecl.n_doc != null then
			var txt = n_moduledecl.n_doc.n_comment.first.text
			txt = txt.replace("# ", "")
			txt = txt.replace("\n", "")
			ret += txt
		end
		return ret
	end
end

# Create a tool context to handle options and paths
var toolcontext = new ToolContext
toolcontext.process_options

# Here we launch the nit index
var nitdoc = new Nitdoc(toolcontext)
nitdoc.start
