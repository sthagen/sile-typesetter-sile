SILE = require("core.sile")
SU.warn = function () end

describe("The papersize parser", function()
  local parse = SILE.papersize
  it("should return the correct values for a6", function()
    local a6 = { 297.6377985, 419.52756359999995 }
    assert.is.same(parse("a6"), a6)
    assert.is.same(parse("A6"), a6)
    assert.is.same(parse("A-6"), a6)
  end)
  it("should return the correct values for arbitrary measurements", function()
    local size = { 144, 288 }
    assert.is.same(parse("2in x 4in"), size)
    assert.is.same(parse("144 x 288"), size)
  end)
  it("should flip x and y page geometry for landscape mode", function()
    local size = { 288, 144 }
    assert.is.same(parse("2in x 4in", true), size)
    assert.is.same(parse("144 x 288", true), size)
  end)
  it("error if unable to parse", function()
    assert.has.errors(function () parse("notapaper") end)
    assert.has.errors(function () parse(nil) end)
    assert.has.errors(function () parse("") end)
    assert.has.errors(function () parse("a4.0") end)
  end)
end)

describe("The measurement convertor", function()
  it("should exist", function()
    assert.is.truthy(SILE.toPoints)
  end)
  it("should work for points, units explicit", function () assert.is.equal(20, SILE.measurement(20, "pt"):tonumber()) end)
  it("should work for points, units implicit", function () assert.is.equal(20, SILE.measurement("20pt"):tonumber()) end)
  it("should work for inches, units implicit", function () assert.is.equal(14.4, SILE.measurement("0.2in"):tonumber()) end)
end)
