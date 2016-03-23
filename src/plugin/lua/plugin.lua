local sys       = require "lemoon.sys"
local fs        = require "lemoon.fs"
local filepath  = require "lemoon.filepath"
local class     = require "lemoon.class"
local console   = class.new("lemoon.log","console")
local logger    = class.new("lemoon.log","gsmake")


local init = function(self)
    cmakeconfig    = self.Owner.Properties.cmake

    local ok, cmake_path = sys.lookup("cmake")

    if not ok then
        throw("check the cmake command line tools -- failed, not found")
    end

    cmake = cmake_path

    local loader = self.Owner.Loader

    outputdir = filepath.toslash(filepath.join(
        loader.Temp,"clang",
        loader.Config.TargetHost .. "-" .. loader.Config.TargetArch))


    if not fs.exists(outputdir) then
        fs.mkdir(outputdir,true)
    end
end

task.resources = function(self)
    init(self)

    local exec = sys.exec(cmake,function(msg)
        logger:I("%s",msg)
    end)

    for _,v in ipairs(cmakeconfig) do
        local name = v.name
        local version = v.version or self.Owner.Loader.Config.DefaultVersion
        console:I("sync cmake project(%s:%s) ...",name,version)
        local path = self.Owner.Loader.Sync:sync(name,version)
        console:I("sync cmake project(%s:%s) -- success",name,version)
        console:I("install cmake project(%s:%s) ...",name,version)

        local cmake_build_dir = filepath.join(
            loader.Temp,"cmake",name,
            loader.Config.TargetHost .. "-" .. loader.Config.TargetArch)

        if not fs.exists(cmake_build_dir) then
            fs.mkdir(cmake_build_dir,true)
        end

        exec:dir(cmake_build_dir)
        local config = self.Owner.Loader.Config
        if config.TargetHost == "Windows" and config.TargetArch == "AMD64" then
            exec:start("-DCMAKE_INSTALL_PREFIX="..outputdir,"-A","x64",path)
        else
            exec:start("-DCMAKE_INSTALL_PREFIX="..outputdir,path)
        end

        if 0 ~= exec:wait() then
            console:E("install cmake project(%s:%s) -- failed",name,version)
            return true
        end

        local buildconfig = self.Owner.Loader.Config.BuildConfig
        local buildclear = self.Owner.Loader.Config.BuildClear

        local buildargs = {"--build",".","--target INSTALL"}

        if buildconfig then
            table.insert(buildargs,"--config")
            table.insert(buildargs,buildconfig)
        end

        if buildclear then
            table.insert(buildargs,"--clean-first")
        end

        exec:start(table.unpack(buildargs))

        if 0 ~= exec:wait() then
            console:E("install cmake project(%s:%s) -- failed",name,version)
            return true
        end

        console:I("install cmake project(%s:%s) -- success",name,version)
    end
end
