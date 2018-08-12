-- Gulp
--
-- Copyright (C) 2018  Annemarie Mattmann
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local conf = {
	world = {
		w = 1920/2,
		h = 800,
	},
	cakeImgSize = 64,
	gulpImgSize = 960,
	poopImgSize = 64,
	gulpMinSize = 10,
	gulpMaxSize = 2
}

local gulpState = {}

local cakeState = {
	cakeBonus = 200
}

local badState = {}

local eatingAnimation = {
	quadIndices = {[0]=3, 4, 3, 4, 5},
	duration = 0.2
}

local poopAnimation = {
	quad = 1,
	duration = 0.2
}

local explodingAnimation = {
	quadIndices = {[0]=6, 7, 6, 7, 8},
	duration = 0.1
}

local player = {
	bestTime = 0,
	lastTime = 0
}

local activePoops = {}

function start()
	gulpState.size = conf.gulpMinSize
	gulpState.speed = {x=0, y=0}
	gulpState.pos = {x=conf.world.h/2, y=conf.world.h-70}
	gulpState.activeQuad = 0
	gulpState.eating = -1
	gulpState.foodCount = 0
	gulpState.exploding = -1
	gulpState.poop = false
	gulpState.poopCount = 2

	cakeState.activeCakes = {}
	cakeState.cakeSpeed = 0.5
	cakeState.cakeCount = 0

	badState.activeBadness = {}

	activePoops = {}

	eatingAnimation.currentTime = 0
	poopAnimation.currentTime = 0
	explodingAnimation.currentTime = 0

	gameOver = false
	startTime = love.timer.getTime()
end

function love.load()
	-- set window properties
	love.window.setTitle("Gulp")
	love.window.setMode(conf.world.w, conf.world.h, {resizable=false, vsync=false})

	-- set graphics properties
	--love.graphics.setDefaultFilter("nearest", "nearest") -- avoid blurry scaling

	-- load images
	cakeSprite = love.graphics.newImage("assets/cake.png")
	cakeQuads = {}
	for i = 0, cakeSprite:getWidth()/conf.cakeImgSize do
		cakeQuads[i] = love.graphics.newQuad(i*conf.cakeImgSize, 0, conf.cakeImgSize, conf.cakeImgSize, cakeSprite:getDimensions())
	end
	gulpSprite = love.graphics.newImage("assets/gulp.png")
	gulpQuads = {}
	for i = 0, gulpSprite:getWidth()/conf.gulpImgSize do
		gulpQuads[i] = love.graphics.newQuad(i*conf.gulpImgSize, 0, conf.gulpImgSize, conf.gulpImgSize, gulpSprite:getDimensions())
	end
	poopImg = love.graphics.newImage("assets/poop.png")
	badSprite = love.graphics.newImage("assets/bad.png")
	badQuads = {}
	for i = 0, badSprite:getWidth()/conf.cakeImgSize do
		badQuads[i] = love.graphics.newQuad(i*conf.cakeImgSize, 0, conf.cakeImgSize, conf.cakeImgSize, cakeSprite:getDimensions())
	end

	-- change default font size
	font = love.graphics.newFont(24)
	love.graphics.setFont(font)

	-- play music
	gulpSound = love.audio.newSource("assets/gulp.ogg", "static")
	nomSound = love.audio.newSource("assets/nom.ogg", "static")
	poopSound = love.audio.newSource("assets/poop.ogg", "static")
	explodeSound = love.audio.newSource("assets/explode.ogg", "static")
	--background = love.audio.newSource("assets/background.ogg", "stream")
	--background:setLooping(true)

	gameStart = true
	welcomeText = "Welcome to Gulp!\nIt's a little monster that likes cakes a bit too much for it's own good.\nYou need to keep it away from it before it grows over your (and it's own) head!\nPay attention to the inedible!\nPress \"a\" to move to the left, \"d\" to move to the right and \"s\" to poop.\n\nPress \"Return\" to start and have fun!"
end

function love.update(dt)
	-- freeze at game over
	if gameStart or gameOver or gulpState.exploding >= #explodingAnimation.quadIndices then
		gameOver = true
		return
	end

	-- generate cakes and bad things
	if love.math.random() < 0.01 then
		if love.math.random() < 0.001 then
			table.insert(badState.activeBadness, {quad=badQuads[0], x=love.math.random(0, conf.world.w - conf.cakeImgSize), y=70})
		else
			table.insert(cakeState.activeCakes, {quad=cakeQuads[love.math.random(0, 3)], x=love.math.random(0, conf.world.w - conf.cakeImgSize), y=70})
		end
	end

	-- move player
	gulpState.pos.x = gulpState.speed.x * dt + gulpState.pos.x
	if gulpState.pos.x < 0 then
		gulpState.speed.x = 0
		gulpState.pos.x = 0
	end
	if gulpState.pos.x > conf.world.w - conf.gulpImgSize/gulpState.size then
		gulpState.speed.x = 0
		gulpState.pos.x = conf.world.w - conf.gulpImgSize/gulpState.size
	end
	-- update y pos
	gulpState.pos.y = conf.world.h-70-conf.gulpImgSize/gulpState.size

	-- set state changing booleans
	spotCake = false
	eatCake = false

	for key, cake in pairs(cakeState.activeCakes) do
		-- move cakes
		cake.y = cake.y + cakeState.cakeSpeed

		-- check cake coming
		if math.abs(gulpState.pos.x - cake.x) < conf.gulpImgSize/gulpState.size/2 and gulpState.pos.y - cake.y < 100 and cake.y < gulpState.pos.y then
			spotCake = true
		end

		-- check cake "collision"
		if math.abs(gulpState.pos.x - cake.x) < conf.gulpImgSize/gulpState.size/2 and math.abs(gulpState.pos.y - cake.y) < 5 then
			eatCake = true
			cakeState.activeCakes[key] = nil
		end

		-- delete cakes moving out of the world
		if cake.y > conf.world.h then
			cakeState.cakeCount = cakeState.cakeCount + 1
			cakeState.activeCakes[key] = nil
		end
	end

	for key, badness in pairs(badState.activeBadness) do
		-- move bad things
		badness.y = badness.y + cakeState.cakeSpeed
		-- check badness coming
		if math.abs(gulpState.pos.x - badness.x) < conf.gulpImgSize/gulpState.size/2 and gulpState.pos.y - badness.y < 100 and badness.y < gulpState.pos.y then
			spotCake = true
		end
		-- check badness "collision"
		if math.abs(gulpState.pos.x - badness.x) < conf.gulpImgSize/gulpState.size/2 and math.abs(gulpState.pos.y - badness.y) < 5 then
			badState.activeBadness[key] = nil
			love.audio.play(explodeSound)
			gulpState.exploding = gulpState.exploding + 1
			gulpState.activeQuad = explodingAnimation.quadIndices[gulpState.exploding]
			endTime = love.timer.getTime() - startTime
			player.bestTime = math.max(endTime, player.bestTime)
			deathReason = "Your little monster ate something it could not digest.\n"
			return
		end
		-- delete bad things moving out of the world
		if badness.y > conf.world.h then
			badState.activeBadness[key] = nil
		end
	end

	-- return to normal if eating animation is over
	if gulpState.eating == #eatingAnimation.quadIndices then
		gulpState.foodCount = gulpState.foodCount + 1
		gulpState.eating = -1
	end
	-- grow if eaten enough
	if gulpState.foodCount >= (conf.gulpMinSize + 1) - gulpState.size then
		gulpState.size = gulpState.size - 1
		gulpState.foodCount = 0
		gulpState.pos.x = gulpState.pos.x - math.abs(conf.gulpImgSize/(gulpState.size + 1) - conf.gulpImgSize/gulpState.size)/2
	end
	-- gain a poop for enough cakes passed
	if cakeState.cakeCount >= cakeState.cakeBonus then
		gulpState.poopCount = gulpState.poopCount + 1
		cakeState.cakeCount = 0
	end

	-- exploding animation
	if gulpState.exploding > -1 then
		explodingAnimation.currentTime = explodingAnimation.currentTime + dt
		if explodingAnimation.currentTime >= explodingAnimation.duration then
			gulpState.exploding = gulpState.exploding + 1
			explodingAnimation.currentTime = 0
		end
		gulpState.activeQuad = explodingAnimation.quadIndices[gulpState.exploding]
	-- poop animation
	elseif gulpState.poop then
		poopAnimation.currentTime = poopAnimation.currentTime + dt
		if poopAnimation.currentTime >= poopAnimation.duration then
			love.audio.play(poopSound)
			gulpState.poopCount = gulpState.poopCount - 1
			poopAnimation.currentTime = 0
			gulpState.foodCount = 0
			gulpState.size = gulpState.size + 1
			gulpState.pos.x = gulpState.pos.x + math.abs(conf.gulpImgSize/(gulpState.size - 1) - conf.gulpImgSize/gulpState.size)/2
			table.insert(activePoops, gulpState.pos.x)
			gulpState.poop = false
		end
		gulpState.activeQuad = poopAnimation.quad
	-- start eating
	elseif eatCake and gulpState.eating < 0 then
		love.audio.play(nomSound)
		gulpState.eating = gulpState.eating + 1
		gulpState.activeQuad = eatingAnimation.quadIndices[gulpState.eating]
	-- eating animation
	elseif gulpState.eating > -1 then
		eatingAnimation.currentTime = eatingAnimation.currentTime + dt
		if eatingAnimation.currentTime >= eatingAnimation.duration then
			gulpState.eating = gulpState.eating + 1
			eatingAnimation.currentTime = 0
		end
		gulpState.activeQuad = eatingAnimation.quadIndices[gulpState.eating]
	-- spot cake
	elseif spotCake then
		love.audio.play(gulpSound)
		gulpState.activeQuad = 2
	else
		gulpState.activeQuad = 0
	end

	-- explode
	if gulpState.size <= conf.gulpMaxSize and gulpState.exploding < 0 then
		love.audio.play(explodeSound)
		gulpState.exploding = gulpState.exploding + 1
		gulpState.activeQuad = explodingAnimation.quadIndices[gulpState.exploding]
		endTime = love.timer.getTime() - startTime
		player.bestTime = math.max(endTime, player.bestTime)
		deathReason = "Your little monster had too much cake. Sorry.\n"
	end

end

function love.draw()
	-- print game help on start
	if gameStart then
		love.graphics.printf({{0, 255, 0, 255}, welcomeText}, 0, math.floor(conf.world.h/3), conf.world.w, "center")
		love.graphics.draw(gulpSprite, gulpQuads[2], conf.world.w/2 - conf.gulpImgSize/conf.gulpMinSize/2, conf.world.h/4 - conf.gulpImgSize/conf.gulpMinSize/2, 0, 1/conf.gulpMinSize, 1/conf.gulpMinSize)
		love.graphics.draw(cakeSprite, cakeQuads[0], conf.world.w/2 - conf.cakeImgSize/2, conf.world.h/4 - conf.gulpImgSize/conf.gulpMinSize - conf.cakeImgSize/2)
		return
	end

	-- header
	love.graphics.draw(poopImg, 10, 0)
	love.graphics.print(tostring(gulpState.poopCount), math.floor(conf.poopImgSize/2), math.floor(conf.poopImgSize/3))
	if not gameOver then
		love.graphics.printf(string.format("Time: %.2f", love.timer.getTime() - startTime), 0, 0, conf.world.w, "center")
	else
		love.graphics.printf(string.format("Time: %.2f", endTime), 0, 0, conf.world.w, "center")
	end
	love.graphics.printf(string.format("Eaten: %i of %i", gulpState.foodCount, (conf.gulpMinSize + 1) - gulpState.size), 0, 0, conf.world.w-10, "right")

	-- game elements
	for key, xPoop in pairs(activePoops) do
		love.graphics.draw(poopImg, xPoop + conf.poopImgSize/2, conf.world.h - conf.poopImgSize)
	end
	love.graphics.draw(gulpSprite, gulpQuads[gulpState.activeQuad], gulpState.pos.x, gulpState.pos.y, 0, 1/gulpState.size, 1/gulpState.size)
	for key, cake in pairs(cakeState.activeCakes) do
		love.graphics.draw(cakeSprite, cake.quad, cake.x, cake.y)
	end
	for key, badness in pairs(badState.activeBadness) do
		love.graphics.draw(badSprite, badness.quad, badness.x, badness.y)
	end

	-- print game stats
	if gameOver then
		currTimeNote = string.format("Time of survival: %.2f seconds.\n", endTime)
		if endTime == player.bestTime then
			bestTimeNote = "This is your current best time!\n"
		else
			bestTimeNote = string.format("This is %.2f below your current best time.\n", player.bestTime - endTime)
		end
		if player.lastTime ~= 0 and player.lastTime ~= endTime then
			if endTime > player.lastTime then
				lastTimeNote = string.format("This is %.2f above your last time.", endTime - player.lastTime)
			else
				lastTimeNote = string.format("This is %.2f below your last time.", player.lastTime - endTime)
			player.lastTime = endTime
			end
		else
			lastTimeNote = ""
			player.lastTime = endTime
		end
		love.graphics.printf({{0, 255, 0, 255}, deathReason .. currTimeNote .. bestTimeNote .. lastTimeNote}, 0, math.floor(conf.world.h/2), conf.world.w, "center")
	end
end

function love.keypressed(key, scancode, isrepeat)
	-- process key input
	if key == "escape" then
		love.event.quit(0)
	end
	if key == "a" and gulpState.exploding < 0 then
		--move left
		gulpState.speed.x = -400
	end
	if key == "d" and gulpState.exploding < 0 then
		-- move right
		gulpState.speed.x = 400
	end
	if key == "s" and gulpState.poopCount > 0 and gulpState.exploding < 0 and gulpState.eating < 0 and gulpState.size < conf.gulpMinSize then
		gulpState.poop = true
	end
	if key == "return" and (gameOver or gameStart) then
		gameStart = false
		start()
	end
end

function love.keyreleased(key, scancode, isrepeat)
	if key == "a" or key == "d" then
		-- stop
		gulpState.speed.x = 0
	end
end
