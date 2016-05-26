{TextLayer} = require 'TextLayer'

#==========================================
# Problem Generation

currentLevel = 4

operators = [
	{label: "+", operation: (a, b) -> a + b}
	{label: "-", operation: (a, b) -> a - b}
	{label: "*", operation: (a, b) -> a * b}
]

generateProblem = (difficulty, level) ->
	maxOperatorIndex = Math.floor(Math.min(difficulty / 2, 2))
	numberOfOperators = (Math.floor(difficulty / 2) % 3) + 1
	maxOperandValue = (Math.floor(difficulty / 6) * 10) + 10
	numberOfOperands = numberOfOperators + 1
	numbers = [0..numberOfOperands].map -> Math.floor(Utils.randomNumber(0, maxOperandValue))
	operators = [0..numberOfOperators].map -> Utils.randomChoice(operators[0..maxOperatorIndex])
	
	label = ""
	answer = 0
	for operatorIndex in [0..(numberOfOperators - 1)]
		label += numbers[operatorIndex] + " " + operators[operatorIndex].label + " "
	label += numbers[numberOfOperators]
	
	label: label
	answer: eval(label) # "cleverly" avoiding implementing order-of-operations
	rewards:
		count: (difficulty - level) + 1
		type: if Math.random(1) > 0.33 then "point" else "time"

#==========================================
# Game "board"

questionScrollComponent = new ScrollComponent
	width: Screen.width
	height: Screen.height

selectedQuestion = null
questionNumberHeight = 100
questionNumberSpacing = 50

#==========================================
# Question Cells

createQuestion = ->
	question = new Layer
		parent: questionScrollComponent.content
		backgroundColor: "white"
		width: Screen.width
		height: questionNumberHeight
	question.setSelected = (selected) ->
		question.backgroundColor = if selected then "blue" else "white"
		question.answerLayer.text = "" if not selected
	question.onTap ->
		selectedQuestion.setSelected false if selectedQuestion
		selectedQuestion = question
		question.setSelected true
		
		question.updatePendingNumber
			number: 0
			sign: 1
			
	question.problem = generateProblem(currentLevel + Utils.randomChoice([-1, 0, 1]))
			
	questionPrompt = new TextLayer
		x: 30
		autoSize: true
		fontSize: 48
		color: "black"
		parent: question
		text: question.problem.label
		
	question.answerLayer = new TextLayer
		x: 400
		width: 304
		height: questionNumberHeight
		fontSize: 48
		color: "red"
		backgroundColor: "yellow"
		parent: question
		text: ""
		
	question.answerBuffer =
		number: null
		sign: 1
		
	question.updatePendingNumber = (newAnswerBuffer) ->
		question.answerBuffer = newAnswerBuffer
		if newAnswerBuffer.number == 0
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "" else "-"
		else
			question.answerLayer.text = newAnswerBuffer.number * newAnswerBuffer.sign

		
	return question	

for questionNumber in [0..5]
	question = createQuestion()
	question.y = questionNumber * (questionNumberHeight + questionNumberSpacing)

#==========================================
# Answer Input

updatePendingNumber = (updateFunction) ->
	selectedQuestion.updatePendingNumber updateFunction(selectedQuestion.answerBuffer)

#==========================================
# Keyboard

keyboardHeight = 432
keyboard = new Layer
	y: Screen.height - keyboardHeight
	width: Screen.width
	height: keyboardHeight
	backgroundColor: ""

keyWidth = Screen.width / 4
keyHeight = keyboardHeight / 4
keySpacing = 2

appendDigit = (digit) ->
	updatePendingNumber (answerBuffer) ->
		number: answerBuffer.number * 10 + digit
		sign: answerBuffer.sign
		
for column in [0..3]
	for row in [0..3]
		if row == 3 and column > 0
			# These keys are "eaten" by the big 0 and submit keys
			continue
		
		key = new Layer
			width: keyWidth - keySpacing
			height: keyHeight - keySpacing
			x: column * keyWidth
			y: row * keyHeight
			parent: keyboard
		key.states.add
			highlight:
				backgroundColor: "rgba(134,255,242,1)"
			normal:
				backgroundColor: "rgba(20,155,131,1)"
		key.onTouchStart (event, layer) ->
			layer.states.switch "highlight", time: 0.1, curve: "easeout"
			
		unhighlight = (event, layer) ->
			layer.states.switch "normal", time: 0.3, curve: "easeout"
		key.states.switchInstant "normal"
		
		keyLabel = new TextLayer
			color: "white"
			parent: key
			autoSize: true
			fontSize: 48
			fontFamily: "Proxima Nova"
		
		if column < 3 && row < 3
			do (digit = row * 3 + column + 1) ->
				keyLabel.text = digit
				key.onTouchEnd (event, layer) ->
					appendDigit digit
					unhighlight event, layer
		else if column == 3 && row == 0
			# Backspace
			keyLabel.text = "bspace"
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					if answerBuffer.number > 0
						number: Math.trunc(answerBuffer.number / 10)
						sign: answerBuffer.sign
					else
						# If there's no number, just remove the negative.
						{ number: 0, sign: 1 }
				unhighlight event, layer
		else if column == 3 && row == 1
			# Plus/minus
			keyLabel.text = "+/–"
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					number: answerBuffer.number
					sign: answerBuffer.sign * -1
				unhighlight event, layer
		else if column == 3 && row == 2
			# Submit
			keyLabel.text = "Submit"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				# TODO
				unhighlight event, layer
		else if column == 0 && row == 3
			# Extra-wide zero key
			keyLabel.text = "0"
			key.onTouchEnd (event, layer) ->
				appendDigit 0
				unhighlight event, layer
			key.width = keyWidth * 3 - keySpacing
			
		keyLabel.center()
		