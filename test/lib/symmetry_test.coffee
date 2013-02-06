require('chai').should()

symmetry = require '../../lib/symmetry'

describe ".format_message", ->
	it "should say that everything good if there is nothing to review", ->
		message = symmetry.format_message [], [{problems:[]}, {}, {problems:[]}], []
		message.split("\n").length.should.equal 1
		message.substr(0, 8).should.equal       "Good job"

		message2 = symmetry.format_message [], [], []
		message2.split("\n").length.should.equal 1
		message2.substr(0, 8).should.equal       "Good job"


	it "should list of overall problems", ->
		message = symmetry.format_message ["meow meow"], [], []
		lines = message.split("\n")

		lines.length.should.equal 3
		lines[1].should.include "meow meow"

	it "should list problems in commits grouped by commit hash and message", ->
		message = symmetry.format_message [], [{problems: []}, {}, {sha: 1337, commit: {message: 'hello'}, problems: ['problem 1', 'problem 2']}], []
		lines = message.split("\n")

		lines.length.should.equal 5
		lines[1].should.include 1337
		lines[1].should.include 'hello'
		lines[2].should.include 'problem 1'
		lines[3].should.include 'problem 2'

	it "should list missing tests", ->
		message = symmetry.format_message [], [], ['file.1', 'file.2']
		lines = message.split("\n")

		lines.length.should.equal 5
		lines[2].should.include 'file.1'
		lines[3].should.include 'file.2'

	it "should show everything together", ->
		message = symmetry.format_message ['overall problem'], [{problems: []}, {}, {sha: 1337, commit: {message: 'hello'}, problems: ['commit problem 1', 'commit problem 2']}, {}], ['file.1', 'file.2']
		message.should.include 'overall problem'
		message.should.include 'commit problem 1'
		message.should.include 'commit problem 2'
		message.should.include 'file.1'
		message.should.include 'file.2'


describe ".find_problems", ->
	it "should not find any problems in empty commits", ->
		[overall, commits] = symmetry.find_problems []
		overall.length.should.equal 0
		commits.length.should.equal 0

	it "should find commits without badge, but ignore merge commits", ->
		[_, commits] = symmetry.find_problems [
			{commit: {message: '[sY:mY:rY] howdy?'}},
			{commit: {message: "scenario for developer activity link to partner"}},
			{commit: {message: "something is missing here"}},
			{commit: {message: "Merge pull request #13"}}]

		commits[0].problems.length.should.equal 0
		commits[1].problems.length.should.equal 1
		commits[1].problems[0].should.equal "No symmetry badge found."
		commits[2].problems.length.should.equal 1
		commits[2].problems[0].should.equal "No symmetry badge found."
		commits[3].problems.length.should.equal 0

	it "should notice if commit wasn't reviewed or tested or both", ->
		[_, commits] = symmetry.find_problems [
			{commit: {message: '[sY:mL:rY] howdy?'}},
			{commit: {message: '[sY:mN:rL] howdy?'}},
			{commit: {message: '[sY:mL:rL] howdy?'}}]

		commits[0].problems.length.should.equal 1
		commits[0].problems[0].should.equal "Manual testing was postponed"
		commits[1].problems.length.should.equal 1
		commits[1].problems[0].should.equal "Commit wasn't reviewed by its author"
		commits[2].problems.length.should.equal 2
		commits[2].problems.should.deep.equal ["Manual testing was postponed", "Commit wasn't reviewed by its author"]

	it "should count number of Ls and Rs for specs and notice if they're off", ->
		[overall, _] = symmetry.find_problems [
			{commit: {message: '[sL:mL:rY] howdy?'}},
			{commit: {message: '[sL:mN:rL] howdy?'}},
			{commit: {message: '[sR:mL:rL] howdy?'}}]

		overall[0].should == 'There are `2` specs postponed and only `1` specs were added later.'

	it "should not raise error if all specs were added", ->
		[overall, _] = symmetry.find_problems [
			{commit: {message: '[sL:mL:rY] howdy?'}},
			{commit: {message: '[sL:mN:rL] howdy?'}},
			{commit: {message: '[sRR:mL:rL] howdy?'}}]

		overall.length.should.equal 0


describe ".find_missing_tests", ->
	it "should return list of files with missing tests", ->
		files = symmetry.find_missing_tests [
			{filename: 'app/models/cat.rb'},
			{filename: 'spec/services/meow_service_spec.rb'},
			{filename: 'app/contexts/something_context.rb'},
			{filename: 'app/models/.gitignore'},
			{filename: 'app/services/meow_service.rb'},
			{filename: 'spec/models/pew.rb'}]

		files.length.should.equal 2
		files.should.deep.equal ["app/models/cat.rb", "app/contexts/something_context.rb"]


	it "should return empty array if all files matches each other", ->
		files = symmetry.find_missing_tests [
			{filename: 'db/seeds.rb'},
			{filename: 'app/controllers/something_controller.rb'},
			{filename: 'app/models/cat.rb'},
			{filename: 'spec/models/cat_spec.rb'}]

		files.length.should.equal 0
