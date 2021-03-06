{TextLayer} = require 'TextLayer'

# Set this to true to cause many questions to be spawned when the level starts.
debugShouldSpawnManyQuestions = false
debugStartingLevel = 1
debugSkipWelcome = false
debugUnlimitedTime = false

#==========================================
# Initial state 

points = 0
currentLevel = null # 1-indexed (for convenience, because it's shown to the user)
exitQuestionIndex = null # Tracks which question index is going to be the exit question in this level--it may not have been added yet.
setGameState = null # Defined later; working around Framer definition ordering issues.
gameState = null

levelRootLayer = new Layer
	width: Screen.width
	height: Screen.height
	backgroundColor: ""
	
clip = (value, min, max) ->
	Math.max(min, Math.min(max, value))
	
isRunningAsAppOnHomeScreen = window.navigator.standalone || false

#==========================================
# Style Stuffz

# Color Palette

medGray = "rgba(216,216,216,1)"
lightGray = "rgba(227,229,230,1)"
darkGray = "rgba(98,101,105,1)"
darkTextColor = "rgba(59,62,64,1)"
pointColor = "rgba(255,190,38,1)"
timeColor = "rgba(1,209,193,1)"
selectColor = "rgba(240, 241, 242, 0.8)"
whiteColor = "white"
yellowColor = "yellow"
transparent = "rgba(0,0,0,0)"

questionBorderColorSelected = whiteColor
questionBorderColorUnselected = "rgba(250, 250, 250, 0.8)"

fontFamily = "Avenir, HelveticaNeue, Helvetia, sans-serif"

background = new Layer
	width: Screen.width,
	height: Screen.height
background.style.background = "linear-gradient(to bottom, #5FA9B4, #04007B)"
background.sendToBack()

# Sizes of things

questionWidthUnselected = 195 * 2
questionWidthSelected = 225 * 2
questionHeightUnselected = 55 * 2
questionHeightSelected = 61 * 2

questionBorderWidthUnselected = 1
questionBorderWidthSelected = 3 * 2

questionPromptSize = 28*2
questionNumberSpacing = 14*2
questionLeftPadding = 25*2
questionRightPadding = 35*2
questionPromptEqualsSignSpacing = 15

keyboardHeight = 432

#==========================================
# Points

header = new Layer
	y: if isRunningAsAppOnHomeScreen then 40 else 0
	backgroundColor: ""

pointsDisplay = new TextLayer
	parent: header
	color: whiteColor
	fontSize: 13*2
	fontFamily: fontFamily
	x: 185
	y: 15
	
pointsIcon = new Layer
	parent: header
	backgroundColor: pointColor
	x: 145
	y: 17
	width: 15*2
	height: 15*2
	borderRadius: 15
	
setPoints = (newPoints) ->
	pointsDisplay.text = newPoints
	points = newPoints
setPoints(0)

#==========================================
# Timer

startingClockTimeInSeconds = 60

endTime = Infinity
pauseTime = null # When set, contains the remaining number of milliseconds before the game should end
lastTimeUpdate = 0

headerHairline = new Layer
	parent: header
	y: 32*2
	backgroundColor: "rgba(255, 255, 255, 0.5)"
	width: Screen.width
	height: 1

timeDisplay = new TextLayer
	parent: header
	color: whiteColor
	fontFamily: fontFamily
	fontSize: 13*2
	y: pointsDisplay.y
	text: ""
	
timeScaleBackground = new Layer
	parent: header
	backgroundColor: "rgba(49, 68, 83, 0.2)"
	x: 122*2
	y: 8*2
	width: 220*2
	height: 15*2
	borderRadius: 15
	clip: true
timeScaleForeground = timeScaleBackground.copy()
timeScaleForeground.props =
	parent: timeScaleBackground
	backgroundColor: timeColor
	x: 0
	y: 0
	clip: false
	
levelDisplay = new TextLayer
	parent: header
	color: whiteColor
	fontFamily: fontFamily
	fontSize: 13*2
	x: 16
	y: pointsDisplay.y
	text: "Level "

pause = -> pauseTime = endTime - performance.now()
unpause = ->
	return if pauseTime == null
	endTime = performance.now() + pauseTime
	pauseTime = null

updateTimer = (timestamp) ->
	requestAnimationFrame updateTimer
	
	return if endTime == Infinity
	
	remainingSeconds = (endTime - timestamp) / 1000
	if pauseTime != null
		remainingSeconds = pauseTime / 1000
	
	if remainingSeconds <= 0 && gameState == "level" && pauseTime == null && (not debugUnlimitedTime)
		setGameState "gameOver"
	
	newTextualDisplayTime = Math.ceil(remainingSeconds)
	if newTextualDisplayTime != lastTimeUpdate
		lastTimeUpdate = newTextualDisplayTime
		timeDisplay.text = newTextualDisplayTime
		timeDisplay.calcSize()
		timeDisplay.maxX = Screen.width - levelDisplay.x
		
	timeScaleForeground.animate
		properties:
			x: -timeScaleBackground.width * (60 - remainingSeconds) / 60
		time: 0.07

requestAnimationFrame updateTimer


addTime = (extraSeconds) ->
	now = performance.now()
	endTime = clip(endTime + extraSeconds * 1000, now, now + 60*1000)
	if pauseTime != null
		pauseTime = clip(pauseTime + extraSeconds * 1000, 0, 60*1000)

#==========================================
# Problem Generation

allOperators = [
	{label: "+", operation: (a, b) -> a + b}
	{label: "-", operation: (a, b) -> a - b}
	{label: "*", operation: (a, b) -> a * b}
]

generateProblem = (difficulty, level) ->
	maxOperatorIndex = Math.floor(clip(difficulty / 2 - 1, 0, 2))
	numberOfOperators = (Math.floor(difficulty / 2) % 3) + 1
	maxOperandValue = (Math.floor(difficulty / 6) * 10) + 10
	numberOfOperands = numberOfOperators + 1
	numbers = [0..(numberOfOperands - 1)].map -> Math.floor(Utils.randomNumber(0, maxOperandValue))
	operators = [0..(numberOfOperators - 1)].map -> Utils.randomChoice(allOperators[0..maxOperatorIndex])
	
	label = ""
	answer = 0
	for operatorIndex in [0..(numberOfOperators - 1)]
		label += numbers[operatorIndex] + " " + operators[operatorIndex].label + " "
	label += numbers[numberOfOperators]
	
	label: label
	answer: eval(label) # "cleverly" avoiding implementing order-of-operations
	reward:
		count: (difficulty - level) + 1
		type: if Math.random(1) > 0.33 then "points" else "time"
	questionsRevealed: Utils.randomChoice([0, 1, 1, 2, 2, 2, 3])

#==========================================
# Game "board"

maximumNumberOfProblems = (levelNumber) ->
	return Math.ceil(levelNumber * levelNumber)

questionScrollComponent = new ScrollComponent
	parent: levelRootLayer
	y: headerHairline.maxY + header.y
	width: Screen.width
	height: Screen.height - headerHairline.maxY - header.y
	scrollHorizontal: false
	contentInset:
		top: 0
		bottom: keyboardHeight

noSelectionKeyboardOverlay = null # Assigned later, in keyboard section. Annoying that Framer won't let you reference functions top-level variables that are defined later in the file.

selectedQuestion = null
setSelectedQuestion = (newSelectedQuestion, animated) -> 
	selectedQuestion?.setSelected false, animated
	selectedQuestion = newSelectedQuestion
	newSelectedQuestion?.setSelected true, animated
	noSelectionKeyboardOverlay?.setVisible (if newSelectedQuestion then false else true)
	
questions = []
completedQuestions = []

updateAllQuestionsFloat = ->
	requestAnimationFrame updateAllQuestionsFloat
	question.updateFloat() for question in questions
requestAnimationFrame updateAllQuestionsFloat

addQuestion = (newQuestion, animated) ->
	if questions.length + completedQuestions.length == exitQuestionIndex
		# That means we're about to add the end question! Neat!
		newQuestion.markAsExitQuestion()
		
	questions.unshift(newQuestion)
	newQuestion.x = Math.floor(Utils.randomNumber(56*2, 93*2))
	newQuestion.updateQuestionsRevealed false
	updateQuestionLayout animated
	
updateQuestionLayout = (animated) ->	
	y = 66*2
	delay = 0
	for question in questions
		question.animate
			properties:
				y: y
			time: if animated then 0.2 else 0
			delay: delay
		question.targetY = y
		y += questionHeightUnselected + questionNumberSpacing
		delay += 0.02
	y += 80*2 - questionNumberSpacing
	for question in completedQuestions
		question.animate
			properties:
				y: y
			time: if animated then 0.2 else 0
			delay: delay
		question.targetY = y
		y += questionHeightUnselected + questionNumberSpacing
		delay += 0.02
			
	setTimeout(->
		questionScrollComponent.updateContent() # Resize the scrollable bounds of the question scroll component according to the new layout
	, (delay + 0.2) * 1000)

#==========================================
# Question Cells

createQuestion = (difficulty, level) ->
	question = new Layer
		parent: questionScrollComponent.content
		backgroundColor: ""
		width: questionWidthUnselected
		height: questionHeightUnselected
	
	questionInterior = question.copy()
	questionInterior.parent = question
	
	updateQuestionBackgroundColor = (animated) ->
		question.questionBorder.animate
			properties:
				backgroundColor: if question.isAnswered then "rgba(255, 255, 255, 0.3)" else ""
			time: if animated then 0.15 else 0
		
	question.setSelected = (selected, animated) ->
		if selected
			time = if animated then 0.15 else 0
			newQuestionWidth = Math.max(question.answerLayer.maxX + questionRightPadding, questionWidthSelected)
			
			questionInterior.animate
				properties: {x: -(newQuestionWidth - questionWidthUnselected) / 2}
				time: time
				
			question.questionBorder.animate
				properties:
					borderWidth: questionBorderWidthSelected
					borderColor: questionBorderColorSelected
					borderRadius: questionHeightSelected / 2
					y: -(questionHeightSelected - questionHeightUnselected) / 2
					width: newQuestionWidth
					height: questionHeightSelected
					shadowColor: whiteColor
				time: time

			question.equalsLabel.animate
				properties: {opacity: 1}
				time: time
				
			question.answerLayer.animate
				properties: {opacity: 1}
				time: time
				
			question.revealedQuestionContainer.animate
				properties: {x: newQuestionWidth}
				time: time
		else
			time = if animated then 0.1 else 0
			newQuestionWidth = Math.max(question.promptLayer.maxX + questionRightPadding, questionWidthUnselected)
			
			questionInterior.animate
				properties: {x: 0}
				time: time
			question.questionBorder.animate
				properties:
					borderWidth: if question.isAnswered then 0 else questionBorderWidthUnselected
					borderColor: questionBorderColorUnselected
					borderRadius: questionHeightUnselected / 2
					width: newQuestionWidth
					height: questionHeightUnselected
					y: 0
					shadowColor: "rgba(255,255,255,0)"
				time: time
			question.equalsLabel.animate
				properties: {opacity: 0}
				time: time
			question.answerLayer.animate
				properties: {opacity: 0}
				time: time
			question.revealedQuestionContainer.animate
				properties: {x: newQuestionWidth}
				time: time
		question.answerLayer.text = "" if not selected and not question.isAnswered
		updateQuestionBackgroundColor animated
		
	question.onTap ->
		return if question.isAnswered
		
		setSelectedQuestion question, true
		question.updatePendingNumber
			number: null
			sign: 1
			
	question.problem = generateProblem(difficulty, level)
	
	question.isAnswered = false
	
	question.markAsExitQuestion = ->
		dot.destroy() for dot in question.revealedQuestionContainer.subLayers
		exitIndicator = new Layer
			parent: question.revealedQuestionContainer
			width: 226
			height: 110
			x: -question.questionBorder.borderRadius
			image: "images/ExitIndicator@2x.png"
		question.isExit = true
			
	question.promptLayer = new TextLayer
		x: questionLeftPadding
		autoSize: true
		fontSize: questionPromptSize
		fontFamily: fontFamily
		color: whiteColor
		parent: questionInterior
		text: question.problem.label
	question.promptLayer.midY = question.height / 2
	
	question.equalsLabel = question.promptLayer.copy()
	question.equalsLabel.props =
		parent: questionInterior
		text: "="
		opacity: 0
		x: question.promptLayer.maxX + questionPromptEqualsSignSpacing
		
	question.answerLayer = question.promptLayer.copy()
	question.answerLayer.props =
		parent: questionInterior
		autoSize: false
		opacity: 0
		text: "foo"
	# this is dumb but if we don't do this then the answerLayer size is technically still 0 and we can't move its midpoint
	question.answerLayer.calcSize()
	question.answerLayer.midY = question.height / 2
	question.answerLayer.x = question.equalsLabel.maxX + questionPromptEqualsSignSpacing
	question.answerLayer.width = 40*2
	question.answerLayer.text = " "
	question.answerLayer.style["border-bottom"] = "6px solid white"
	question.answerBuffer = {number: null, sign: 1}
	
	# Make reward circles
	rewardX = 0
	question.rewardLayers = []
	for rewardIndex in [0...question.problem.reward.count]
		size = 45*2 - rewardIndex*10*2
		rewardX -= (size - 11*2)
		rewardLayer = new Layer
			parent: questionInterior
			width: size
			height: size
			borderRadius: size/2
			opacity: 0.8 - 0.2*rewardIndex
			backgroundColor: if question.problem.reward.type == "points" then pointColor else timeColor
			x: rewardX
		rewardLayer.midY = questionInterior.height / 2
		
		# CoffeeScript's scope binding semantics are ridiculous; rewardLayer and rewardIndex are reassigned on every loop iteration and captured by-reference. This do() syntax avoids that. Feh!
		do (rewardIndex, rewardLayer) ->
			rewardLayer.giveReward = ->
				targetLayer = if question.problem.reward.type == "points" then pointsIcon else timeScaleBackground
				rewardLayerScreenFrame = rewardLayer.screenFrame
				targetLayerScreenFrame = targetLayer.screenFrame
				rewardLayer.parent = levelRootLayer
				rewardLayer.screenFrame = rewardLayerScreenFrame
				scale = targetLayer.height / rewardLayer.height
				animation = rewardLayer.animate
					properties:
						midX: targetLayerScreenFrame.x + rewardLayer.width * scale / 2
						midY: targetLayerScreenFrame.y + targetLayerScreenFrame.height / 2
						scale: scale
					time: 0.4
					delay: 0.1 * rewardIndex
				animation.on(Events.AnimationEnd, (animation) ->
					rewardLayer.destroy()
					switch question.problem.reward.type
						when "points"
							setPoints points + 1
						when "time"
							# Give 3 seconds per "time unit".
							addTime 3
				)
		question.rewardLayers.push rewardLayer
					
	question.questionBorder = new Layer
		parent: questionInterior
		borderColor: questionBorderColorUnselected
		borderRadius: questionHeightUnselected / 2
		borderWidth: questionBorderWidthUnselected
		shadowBlur: 22*2
		shadowSpread: 4*2
		width: question.width
		height: question.height
		backgroundColor: ""
		shadowColor: transparent
		
	question.updatePendingNumber = (newAnswerBuffer) ->
		question.answerBuffer = newAnswerBuffer
		question.answerLayer.color = whiteColor
		if newAnswerBuffer.number == 0
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "0" else "-0"
		else if newAnswerBuffer.number == null
			question.answerLayer.text = if newAnswerBuffer.sign == 1 then "" else "-"
		else
			question.answerLayer.text = newAnswerBuffer.number * newAnswerBuffer.sign
			
	question.ghostifyAnswer = ->
		question.answerLayer.color = "rgba(255, 255, 255, 0.4)"
		question.answerBuffer = {number: null, sign: 1}
		
	question.giveRewards = ->
		for rewardLayer in question.rewardLayers
			rewardLayer.giveReward()

	# Make revealed question circles
	question.revealedQuestionContainer = new Layer
		parent: questionInterior
		backgroundColor: ""
		x: questionInterior.width

	question.revealedQuestionDots = []
	
	# This is kind of an interesting thing: the number of questions a question might reveal may change over time... so we need to be able to update the number of dots displayed.
	question.updateQuestionsRevealed = (animated) ->
		isLastAvailableQuestion = questions.length <= 1
		effectiveNumberOfQuestionsRevealed = clip(
			question.problem.questionsRevealed,
			if isLastAvailableQuestion then 2 else 0, 
			maximumNumberOfProblems(level) - (questions.length + completedQuestions.length)
		)
		
		effectiveNumberOfQuestionsRevealed = 0 if question.isExit
		
		revealedQuestionDots = []
		revealedQuestionDotX = -11*2
		for questionIndex in [0...effectiveNumberOfQuestionsRevealed]
			size = 45*2 - questionIndex*10*2
			revealedQuestionLayer = new Layer
				parent: question.revealedQuestionContainer
				width: size
				height: size
				borderRadius: size/2
				opacity: 0.6 - 0.1*questionIndex
				borderColor: whiteColor
				borderWidth: 1
				backgroundColor: ""
				x: revealedQuestionDotX
			revealedQuestionLayer.midY = questionInterior.height / 2
			revealedQuestionDotX += size - 11*2
			revealedQuestionDots.push(revealedQuestionLayer)
		
		oldDotCount = question.revealedQuestionDots.length
		newDotCount = revealedQuestionDots.length
		
		if newDotCount >= oldDotCount
			# Animate in all the newborn dots
			for newDotIndex in [oldDotCount...newDotCount]
				dot = revealedQuestionDots[newDotIndex]
				do (dot) ->
					dot.opacity = 0
					dot.animate
						properties: {opacity: 1}
						time: if animated then 0.1 else 0
			oldDot.destroy() for oldDot in question.revealedQuestionDots
		else
			# Animate out all the dying dots
			for oldDotIndex in [newDotCount...oldDotCount]
				dot = question.revealedQuestionDots[oldDotIndex]
				do (dot) ->
					dot.animate
						properties: {opacity: 0}
						time: 0.1
					.on(Events.AnimationEnd, ->
						dot.destroy()
					)
			oldDot.destroy() for oldDot in question.revealedQuestionDots[0...newDotCount]
				
		question.revealedQuestionDots = revealedQuestionDots
		
	question.phase = Utils.randomNumber(0, 2 * Math.PI)
	question.updateFloat = ->
		periodX = 700 + Math.random(0, 100)
		periodY = 2000 + Math.random(0, 200)
		phase = question.phase
		amplitudeX = 0.04
		amplitudeY = 0.06
		questionInteriorDeltaX = Math.sin(performance.now() / periodX + phase) * amplitudeX / 2
		questionInteriorDeltaY = Math.sin(performance.now() / periodY + phase) * amplitudeY / 2
		questionInterior.x += questionInteriorDeltaX
		questionInterior.y += questionInteriorDeltaY
		systemX = 0
		systemY = 0
		for rewardLayerIndex in [0...question.rewardLayers.length]
			phase += rewardLayerIndex
			rewardLayer = question.rewardLayers[rewardLayerIndex]
			systemX += Math.sin(performance.now() / periodX + phase) * amplitudeX
			systemY += Math.sin(performance.now() / periodY + phase) * amplitudeY
			rewardLayer.x += systemX
			rewardLayer.y += systemY
		systemX = 0
		systemY = 0
		for revealedQuestionIndex in [0...question.revealedQuestionDots.length]
			phase += revealedQuestionIndex
			revealedQuestionDot = question.revealedQuestionDots[revealedQuestionIndex]
			systemX += Math.sin(performance.now() / periodX + phase) * amplitudeX
			systemY += Math.sin(performance.now() / periodY + phase) * amplitudeY
			revealedQuestionDot.x += systemX
			revealedQuestionDot.y += systemY
		
	question.updateQuestionsRevealed false

	# For correct / incorrect
	addEphemeralIcon = (iconName, width, height, rightMargin) ->
		iconLayer = new Layer
			parent: question.revealedQuestionContainer
			image: iconName
			width: width
			height: height
			x: rightMargin
			opacity: 0
			scale: 0.5
		iconLayer.midY = questionInterior.height / 2
		
		iconLayer.animate
			properties:
				opacity: 1
				scale: 1
			curve: "spring(400, 50, 100)"
		
		return iconLayer
			
	question.submit = ->
		return if question.isAnswered
		
		userAnswer = question.answerBuffer.number * question.answerBuffer.sign
		isCorrect = userAnswer == question.problem.answer
		if isCorrect
			addEphemeralIcon "images/Correct@2x.png", 68, 52, -50
			question.isAnswered = true
			updateQuestionBackgroundColor true
			
			# Let the icon come in for a moment.
			pause() if question.isExit # But stop the clock before then!
			setTimeout(->				
				if question.isExit
					# Give rewards for all remaining unanswered questions.
					for question in questions
						question.giveRewards()

					setTimeout(->
						setGameState "levelComplete"
					, 500)
				else
					question.giveRewards()
					
					questions.splice(questions.indexOf(question), 1)
					completedQuestions.unshift(question)
					question.isAnswered = true
										
					setSelectedQuestion null, true
					
					# Reveal new questions:
					effectiveNumberOfQuestionsRevealed = question.revealedQuestionDots.length
					newQuestions = []
					for questionNumber in [0...effectiveNumberOfQuestionsRevealed]
						# New question difficulty is based on previous question difficulty, but the difficulty level can only shift by 1 (either direction) each time, and it can never be more than 2 levels of difficult beyond the base level number.
						newDifficulty = clip(difficulty + Utils.randomChoice([-1, 0, 1]), level, level + 2)
						
						newQuestion = createQuestion(newDifficulty, level)
						newQuestion.opacity = 0
						addQuestion newQuestion, true
						newQuestions.push(newQuestion)
						
					otherQuestion.updateQuestionsRevealed true for otherQuestion in questions

					updateQuestionLayout true
						
					delay = 0
					for questionNumber in [0...effectiveNumberOfQuestionsRevealed]
						dot = question.revealedQuestionDots[questionNumber]
						newQuestion = newQuestions[questionNumber]
						delay = 0.1 * (effectiveNumberOfQuestionsRevealed - 1 - questionNumber)
						newQuestionFadeAnimation = newQuestion.animate
							properties: {opacity: 1}
							delay: (if dot then 0.4 else 0.1) + delay
							time: 0.2
							
						if dot
							dot.parent = newQuestion.parent
							dot.x += question.x + questionInterior.x + question.revealedQuestionContainer.x
							dot.y += question.y
							dot.animate
								properties: {y: newQuestion.targetY}
								time: 0.4
							dot.animate
								properties: {x: newQuestion.x}
								time: 0.3
								delay: 0.1 + delay
							dot.animate
								properties:
									width: newQuestion.width
									height: newQuestion.height
									borderRadius: newQuestion.height / 2
								time: 0.3
								delay: 0.1 + delay
							
							do (dot) ->
								newQuestionFadeAnimation.on(Events.AnimationEnd, ->
									dot.destroy()
								)
			, 200) # in milliseconds
		else
			incorrectIcon = addEphemeralIcon "images/Incorrect@2x.png", 44, 44, -36
			 
			# After a little bit, reverse the animation.
			setTimeout(->
				disappearAnimation = incorrectIcon.animate
					properties:
						scale: 0
					time: 0.2
				disappearAnimation.on(Events.AnimationEnd, -> incorrectIcon.destroy())
			, 600) # in milliseconds
			
			question.ghostifyAnswer()
		
	question.setSelected false, false
	
	# Update the base question's size based on the prompt size.
	question.width = Math.max(question.promptLayer.maxX + questionRightPadding, questionWidthUnselected)
	
	return question	

#==========================================
# UI button

createButton = (text, action) ->
	button = new Layer
		width: 220*2
		height: 55*2
		borderRadius: 55
		borderColor: timeColor
		borderWidth: 1
	button.states.add
		normal:
			backgroundColor: ""
		highlight:
			backgroundColor: "rgba(1, 209, 193, 0.1)"
	button.states.switchInstant "normal"
	button.onTouchStart ->
		button.states.switch "highlight", time: 0.1, curve: "easeout"
	button.onTouchEnd ->
		button.states.switch "normal", time: 0.3, curve: "easeout"
		action()
			
	button.buttonLabel = new TextLayer
		parent: button
		fontSize: 18*2
		fontFamily: fontFamily
		color: timeColor
		autoSize: true
		text: text
	button.buttonLabel.midX = button.width / 2
	button.buttonLabel.midY = button.height / 2
	return button

#==========================================
# Level interstitial UI (used for level complete and game over)

interstitialBackground = new Layer
	opacity: 0
	width: Screen.width
	height: Screen.height
	backgroundColor: "rgba(1, 209, 193, 0.75)"
interstitialBackground.style["-webkit-backdrop-filter"] = "blur(6px)"

createInterstitial = (height, headerText, scoreText, timeText, buttonTitle, buttonAction) ->
	interstitialLayer = new Layer
		width: Screen.width
		height: Screen.height
		x: Screen.width
		backgroundColor: ""

	interstitialBoxLayer = new Layer
		parent: interstitialLayer
		width: Screen.width - 32*4
		height: height
		x: 32*2
		midY: Screen.height / 2
		backgroundColor: "rgba(250, 250, 250, 0.95)"
		borderRadius: 4*2
		shadowBlur: 70*2
		shadowColor: "rgba(0, 0, 0, 0.5)"
	
	interstitialHeaderLabel = new TextLayer
		parent: interstitialBoxLayer
		color: darkTextColor
		y: 28*2
		width: interstitialBoxLayer.width
		textAlign: "center"
		fontFamily: fontFamily
		fontSize: 30*2
		text: headerText
	
	interstitialScoreLabel = new TextLayer
		parent: interstitialBoxLayer
		color: darkTextColor
		width: interstitialBoxLayer.width
		y: if scoreText then 137*2 else 85*2
		textAlign: "center"
		fontFamily: fontFamily
		fontSize: 18*2
		text: scoreText || ""
		
	if scoreText
		interstitialPointsIcon = new Layer
			parent: interstitialBoxLayer
			backgroundColor: pointColor
			opacity: 0.8
			y: 85*2
			midX: interstitialBoxLayer.width / 2
			width: 45*2
			height: 45*2
			borderRadius: 45
	else
		interstitialLayer.interior = new Layer
			parent: interstitialBoxLayer
			backgroundColor: ""
			width: interstitialBoxLayer.width - 19*4
			height: height
			x: 19*2
			y: 80*2
	
	if timeText
		interstitialTimeIcon = interstitialPointsIcon.copy()
		interstitialTimeIcon.props =
			parent: interstitialBoxLayer
			backgroundColor: timeColor
			y: 181*2
			
		interstitialTimeLabel = interstitialScoreLabel.copy()
		interstitialTimeLabel.props =
			parent: interstitialBoxLayer
			textAlign: "center"
			y: 233*2
			text: timeText
		
	nextLevelButton = createButton buttonTitle, ->
		buttonAction()
				
		levelRootLayer.x = Screen.width
		levelRootLayer.animate
			properties: {x: 0}
			delay: 0.15
			time: 0.3
		
		interstitialLayer.animate
			properties: {x: -Screen.width}
			time: 0.3
		.on(Events.AnimationEnd, ->
			interstitialLayer.destroy()
		)
			
		interstitialBackground.animate
			properties: {opacity: 0}
			time: 0.2
		
	nextLevelButton.props =
		parent: interstitialBoxLayer
		midX: interstitialBoxLayer.width / 2
		y: Align.bottom(-32*2)
		
	return interstitialLayer
	
presentInterstitial = (interstitialLayer, animated) ->
	levelRootLayer.animate
		properties: {x: -Screen.width}
		time: if animated then 0.45 else 0

	interstitialBackground.bringToFront()
	interstitialLayer.bringToFront()
	interstitialLayer.x = Screen.width
	interstitialLayer.animate
		properties: {x: 0}
		delay: if animated then 0.2 else 0
		time: if animated then 0.35 else 0
		
	interstitialBackground.animate
		properties: {opacity: 1}
		time: if animated then 0.4 else 0

#==========================================
# Game over UI

gameOverLayer = new Layer
	width: Screen.width
	height: Screen.height
	visible: false
	backgroundColor: ""
gameOverLabel = new TextLayer
	parent: gameOverLayer
	color: "white"
	y: 300
	autoSize: true
	text: "Game Over!"
	fontFamily: fontFamily
	fontSize: 80
gameOverLabel.midX = gameOverLayer.midX

gameOverScoreLabel = new TextLayer
	parent: gameOverLayer
	color: "white"
	y: 500
	autoSize: true
	fontFamily: fontFamily
	fontSize: 48
	
retryButton = createButton "Play again", ->
	setGameState "newGame"
retryButton.parent = gameOverLayer
retryButton.y = 700

#==========================================
# Game state

levelStartingEndTime = null
levelStartingPoints = null
highScore = 0

setGameState = (newGameState) ->
	return if newGameState == gameState
	gameState = newGameState
	switch newGameState
		when "welcome"
			welcomeInterstitial = createInterstitial(
				530*2,
				"Welcome!",
				null,
				null,
				"Let's play!", ->
					setGameState "newGame"
			)
			welcomeInterstitial.interior.html = """
			This prototype explores facilitating
			player “flow” by offering choice.<br /><br />
			
			It’s based on the thesis of <a href="http://www.jenovachen.com" target="_blank">Jenova
			Chen</a>, which included a prototype
			called <a href="http://jenovachen.com/flowingames/implementations/math/index.htm" target="_blank">ActiveQuiz</a>. He previously
			helped create <a href="http://thatgamecompany.com/games/flow/" target="_blank">Flow</a> and <a href="http://thatgamecompany.com/games/journey/" target="_blank">Journey</a>.<br /><br />
			
			For the best experience, add this web page to your home screen.<br /><br />
			
			For feedback, please <a href="mailto:andy@khanacademy.org,mayli@khanacademy.org?cc=long-term-research-team-blackhole@khanacademy.org">email us</a>.<br /><br />
			
			Thank you! <br />
			&mdash; May-Li and Andy, <a href="http://klr.tumblr.com" target="_blank">KLR</a><br />
			"""
			style = document.createElement('style');
			style.type = 'text/css';
			style.appendChild(document.createTextNode("a { color: #{timeColor}; text-decoration: none; }"));
			document.getElementsByTagName('head')[0].appendChild(style);
			welcomeInterstitial.interior.style =
				"fontFamily": fontFamily
				"fontSize": "#{17*2}px"
				"color": darkTextColor
				"lineHeight": "#{22*2}px"
				"pointerEvents": "auto"
			presentInterstitial welcomeInterstitial, false
		when "newGame"
			currentLevel = debugStartingLevel
			endTime = performance.now() + startingClockTimeInSeconds * 1000
			setPoints 0
			setGameState "level"
			
		when "level"
			setSelectedQuestion null, false
			
			for question in questions
				question.destroy()
			for question in completedQuestions
				question.destroy()
			questions = []
			completedQuestions = []
			
			levelRootLayer.visible = true
			gameOverLayer.visible = false
			
			levelDisplay.text = "Level #{currentLevel}"
			
			exitQuestionIndex = Math.round(Utils.randomNumber(Math.floor(maximumNumberOfProblems(currentLevel) / 2), maximumNumberOfProblems(currentLevel) - 1))

			# We may want to add multiple questions at the start of a level in the future: this is where we'd do that!
			initialQuestion = createQuestion(currentLevel, currentLevel)
			addQuestion initialQuestion
			setSelectedQuestion initialQuestion, false
			
			if debugShouldSpawnManyQuestions
				addQuestion createQuestion(currentLevel + Utils.randomChoice([0, 1, 2]), currentLevel) for _ in [0..5]
			
			levelStartingEndTime = endTime
			levelStartingPoints = points

		when "levelComplete"			
			secondsEarned = Math.floor(Math.max(0, endTime - levelStartingEndTime) / 1000)

			presentInterstitial createInterstitial(
				419*2,
				"Level #{currentLevel} Complete!",
				"#{points - levelStartingPoints} points earned!", 
				"#{secondsEarned} seconds earned\n#{timeDisplay.text} seconds left!",
				"Onward to Level #{currentLevel + 1}!",
				->
					currentLevel += 1
					setGameState "level"
					# Don't unpause for a moment: there are animations.
					setTimeout(->
						unpause()
					, 1000)
			), true
			
		when "gameOver"
			scoreString = if points > highScore
				highScore = points
				"New personal best!\nTotal score: #{points} points"
			else
				"Total score: #{points} points\nPersonal best: #{highScore} points"
			presentInterstitial createInterstitial(
				300*2,
				"Time's Up!",
				scoreString,
				null
				"Play again",
				->
					setGameState "newGame"
			), true

#==========================================
# Answer Input

updatePendingNumber = (updateFunction) ->
	selectedQuestion.updatePendingNumber updateFunction(selectedQuestion.answerBuffer)

#==========================================
# Keyboard

keyboardContainer = new Layer
	y: Screen.height - keyboardHeight - 1
	width: Screen.width
	height: keyboardHeight + 1
	backgroundColor: ""
	
blurStyle = "blur(50px)"
keyboardContainer.style["-webkit-backdrop-filter"] = blurStyle
if !CSS.supports("-webkit-backdrop-filter", blurStyle)
	# Can't scroll under the keyboard if we don't have backdrops.
	newInset = 110
	questionScrollComponent.height -= keyboardHeight
	questionScrollComponent.contentInset = 
		top: questionScrollComponent.contentInset.top
		bottom: newInset
	questionScrollComponent.updateContent()

keyboard = keyboardContainer.copy()
keyboard.parent = keyboardContainer
keyboard.y = 1

keyWidth = Screen.width / 4
keyHeight = keyboardHeight / 4
keySpacing = 1

appendDigit = (digit) ->
	updatePendingNumber (answerBuffer) ->
		number: answerBuffer.number * 10 + digit
		sign: answerBuffer.sign
		
for column in [0..3]
	for row in [0..3]
		if (row == 3 and column > 1) or (row == 1 and column == 3)
			# These keys are "eaten" by the big 0, backspace, and submit keys
			continue
		
		key = new Layer
			width: keyWidth - keySpacing
			height: keyHeight - keySpacing
			x: column * keyWidth
			y: row * keyHeight
			parent: keyboard
		key.states.add
			highlight:
				backgroundColor: "rgba(240, 241, 242, 0.6)"
			normal:
				if column == 3
					backgroundColor: "rgba(240, 241, 242, 0.4)"
				else
					backgroundColor: "rgba(240, 241, 242, 0.5)"
		key.onTouchStart (event, layer) ->
			layer.states.switch "highlight", time: 0.1, curve: "easeout"
			
		unhighlight = (event, layer) ->
			layer.states.switch "normal", time: 0.3, curve: "easeout"
		key.states.switchInstant "normal"
		
		keyLabel = new TextLayer
			color: whiteColor
			parent: key
			autoSize: true
			fontSize: 22*2
			fontFamily: fontFamily
		
		if column < 3 && row < 3
			do (digit = row * 3 + column + 1) ->
				keyLabel.text = digit
				key.onTouchEnd (event, layer) ->
					appendDigit digit
					unhighlight event, layer
		else if column == 3 && row == 0
			# Backspace
			keyLabel.visible = false
			icon = new Layer
				parent: key
				image: "images/backspace@3x.png"
				width: 70.5
				height: 43.5
				x: Align.center
				y: Align.center(55)
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					if answerBuffer.number > 0
						newNumber = Math.trunc(answerBuffer.number / 10)
						
						# If we'd be going from e.g. "9" to "0", go to a blank field instead.
						number: if newNumber > 0 then newNumber else null
						sign: answerBuffer.sign
					else if answerBuffer.number == 0
						# There's an explicitly-typed zero, which we'll now remove (but we'll leave a negative sign if there is one).
						{ number: null, sign: answerBuffer.sign }
					else
						# If there's no number, just remove the negative.
						{ number: null, sign: 1 }
				unhighlight event, layer
		else if column == 3 && row == 2
			# Submit
			keyLabel.text = "check"
			key.height = keyHeight * 2 - keySpacing
			key.onTouchEnd (event, layer) ->
				selectedQuestion.submit()
				unhighlight event, layer
		else if column == 0 && row == 3
			# Plus/minus
			keyLabel.text = "– / +" # TODO(andy) needs an asset
			key.onTouchEnd (event, layer) ->
				updatePendingNumber (answerBuffer) ->
					number: answerBuffer.number
					sign: answerBuffer.sign * -1
				unhighlight event, layer
		else if column == 1 && row == 3
			# Extra-wide zero key
			keyLabel.text = "0"
			key.onTouchEnd (event, layer) ->
				appendDigit 0
				unhighlight event, layer
			key.width = keyWidth * 2 - keySpacing
			
		keyLabel.center()

noSelectionKeyboardOverlay = new Layer
	parent: keyboardContainer
	width: keyboard.width
	height: keyboard.height
	x: keyboard.x
	y: keyboard.y
	backgroundColor: "rgba(240, 241, 242, 0.4)"
noop = (event) -> return
noSelectionKeyboardOverlay.setVisible = (isVisible) ->
	if isVisible
		noSelectionKeyboardOverlay.visible = true
	
	animationLengthInSeconds = 0.2
	noSelectionKeyboardOverlay.animate
		properties: {opacity: if isVisible then 1 else 0}
		time: animationLengthInSeconds
	keyboard.animate
		properties: {opacity: if isVisible then 0 else 1}
		time: animationLengthInSeconds
	if not isVisible
		setTimeout(->
			noSelectionKeyboardOverlay.visible = false
		, animationLengthInSeconds * 1000)

noSelectionKeyboardOverlayLabel = new TextLayer
	parent: noSelectionKeyboardOverlay
	text: "Select a question"
	autoSize: true
	color: whiteColor
	fontFamily: fontFamily
	fontSize: 48
noSelectionKeyboardOverlayLabel.midX = keyboard.midX
noSelectionKeyboardOverlayLabel.midY = keyboard.height / 2

setGameState if debugSkipWelcome then "newGame" else "welcome"
