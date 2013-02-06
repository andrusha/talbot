require('chai').should()

require '../../lib/core_ext'

describe 'Array::difference', ->
	it 'should compute difference between arrays correctly', ->
		[1,2,3,4].difference([2,4]).should.be.deep.equal [1,3]

	it 'should handle empty arrays', ->
		[].difference([2,4]).should.be.deep.equal []
		[2, 4].difference([]).should.be.deep.equal [2,4]

describe 'String::trunc', ->
	it 'should not truncate strings shorter than n', ->
		"meow meow".trunc(50).should.equal "meow meow"

	it 'should truncate and add ellipsis to the string longer than n', ->
		"meow meow".trunc(4).should.equal "meow..."
