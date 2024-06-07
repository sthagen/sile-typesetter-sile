SILE = require("core.sile")

describe("The node factory", function ()
   it("should exist", function ()
      assert.is.truthy(SILE.types.node)
   end)

   describe("hboxes", function ()
      local hbox = SILE.types.node.hbox({ width = 20, height = 30, depth = 3 })
      it("should have width", function ()
         assert.is.equal(20, hbox.width:tonumber())
      end)
      it("should have height", function ()
         assert.is.equal(30, hbox.height:tonumber())
      end)
      it("should have depth", function ()
         assert.is.equal(3, hbox.depth:tonumber())
      end)
      it("should have type", function ()
         assert.is.equal("hbox", hbox.type)
      end)
      it("should be a box (not glue)", assert.is.truthy(hbox.is_box) and assert.falsy(hbox.is_glue))
      it("should not be discardable", function ()
         assert.is.falsy(hbox.discardable)
      end)
      it("should stringify", function ()
         assert.is.equal("H<20pt>^30pt-3ptv", tostring(hbox))
      end)
   end)

   describe("vboxes", function ()
      local hbox1 = SILE.types.node.hbox({ width = 10, height = 5, depth = 2 })
      local hbox2 = SILE.types.node.hbox({ width = 11, height = 6, depth = 3 })
      local vbox = SILE.types.node.vbox({ height = 4, depth = 3, nodes = { hbox1, hbox2 } })
      it("should have nodes", function ()
         assert.is.equal(2, #vbox.nodes)
      end)
      it("should have height", function ()
         assert.is.equal(6, vbox.height:tonumber())
      end)
      it("should have depth", function ()
         assert.is.equal(3, vbox.depth:tonumber())
      end)
      it("should have type", function ()
         assert.is.equal("vbox", vbox.type)
      end)
      it("should be a box (not glue)", assert.is.truthy(vbox.is_box) and assert.falsy(vbox.is_glue))
      it("should not be discardable", function ()
         assert.is.falsy(vbox.discardable)
      end)
      it("should stringify", function ()
         assert.is.equal("VB<6pt|VB[hboxhbox]v3pt)", tostring(vbox))
      end)
   end)

   describe("nnodes", function ()
      local hbox1 = SILE.types.node.hbox({ width = 10, height = 5, depth = 3 })
      local hbox2 = SILE.types.node.hbox({ width = 20, height = 10, depth = 5 })
      local nnode = SILE.types.node.nnode({ text = "test", nodes = { hbox1, hbox2 } })
      it("should have width", function ()
         assert.is.equal(30, nnode.width:tonumber())
      end)
      it("should have depth", function ()
         assert.is.equal(5, nnode.depth:tonumber())
      end)
      it("should have height", function ()
         assert.is.equal(10, nnode.height:tonumber())
      end)
      it("should have type", function ()
         assert.is.equal("nnode", nnode.type)
      end)
      it("should have text", function ()
         assert.is.equal("test", nnode:toText())
      end)
      it("should stringify", function ()
         assert.is.equal("N<30pt>^10pt-5ptv(test)", tostring(nnode))
      end)
   end)

   describe("discs", function ()
      local nnode1 = SILE.types.node.nnode({ width = 20, height = 30, depth = 3, text = "pre" })
      local nnode2 = SILE.types.node.nnode({ width = 20, height = 30, depth = 3, text = "break" })
      local nnode3 = SILE.types.node.nnode({ width = 20, height = 30, depth = 3, text = "post" })
      local discretionary =
         SILE.types.node.discretionary({ prebreak = { nnode1, nnode2 }, postbreak = { nnode3, nnode2 } })
      it("should stringify", function ()
         assert.is.equal(
            "D(N<20pt>^30pt-3ptv(pre)N<20pt>^30pt-3ptv(break)|N<20pt>^30pt-3ptv(post)N<20pt>^30pt-3ptv(break)|)",
            tostring(discretionary)
         )
      end)
   end)

   describe("glues", function ()
      local glue = SILE.types.node.glue({ width = SILE.types.length({ length = 3, stretch = 2, shrink = 2 }) })
      it("should have width", function ()
         assert.is.equal(3, glue.width:tonumber())
      end)
      it("should be discardable", function ()
         assert.is.truthy(glue.discardable)
      end)
      it("should stringify", function ()
         assert.is.equal("G<3pt plus 2pt minus 2pt>", tostring(glue))
      end)
   end)

   describe("vboxs", function ()
      local nnode1 = SILE.types.node.nnode({ width = 20, height = 30, depth = 3, text = "one" })
      local glue = SILE.types.node.glue({ width = SILE.types.length({ length = 3, stretch = 2, shrink = 2 }) })
      local nnode2 = SILE.types.node.nnode({ width = 20, height = 30, depth = 7, text = "two" })
      local nnode3 = SILE.types.node.nnode({ width = 20, height = 30, depth = 2, text = "three" })
      local vbox = SILE.types.node.vbox({ nodes = { nnode1, glue, nnode2, glue, nnode3 } })
      it("should go to text", function ()
         assert.is.equal("VB[one two three]", vbox:toText())
      end)
      it("should have depth", function ()
         assert.is.equal(7, vbox.depth:tonumber())
      end)
   end)
end)
