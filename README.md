# Ball Clock Simulator

>*What is a Ball Clock and why do I need a simulator for it?*

Start with this [YouTube video](https://www.youtube.com/watch?v=F7K6GIBWPQw) that describes exactly what a Ball Clock is.  It gives you a good overview of how it works.

>*Okay, so now I know what a Ball Clock is.  What exactly does your program simulate?*

I have one of these clocks.  One day, I was staring at it and I thought: "If all the balls are in the input tray ready to tee up (when the clock shows 1:00), they're in a certain order.  I wonder how long the clock has to run before the balls return to that same ordering again."  It turns out I'm not the only one to ask this question.  The [Ball Clock Problem](http://www.chilton.com/~jimw/ballclk.html) has been rattling around the internet as far back as 1995.  Just go to Bitbucket or GitHub, type "Ball Clock", and you'll get lots of hits.  Like those simulations, my program runs the clock and counts the number of days that pass until the balls all return to their original starting order in the input tray.

>*Nice!  So how is your Ball Clock Simulator different?*

* First: I wrote it :-)

* Second: I wanted to simulate the little cam mechanism as being either present or not.  I haven't seen this on other simulators.  In the [YouTube video](https://www.youtube.com/watch?v=F7K6GIBWPQw), starting at 2:10, you'll hear a description of a little plastic lever (what I call the "cam") that prevents the balls in the 5-min rail from colliding with the balls in the hr-rail when the clock strikes 1:00.  The physical clock would have issues if that cam were not present, but there's no need for it in a virtual clock.  When you think about it for a bit, you realize that the combinatorics are completely different depending on whether or not that cam is present.  I wanted to see what a difference it made.  By the way, all the other simulators I've seen assume it's not present.

* Third: Mine's got a nice GUI, allows you to run different scenarios from 27 to 1,000 balls, and gives you the option to save your results to a csv file.

* Finally: If you're really digging into this you'll notice that my simulator gives different results than what you would see in some others.  I must respectfully disagree with my esteemed colleagues.  The other simulators I've seen assume that the last ball to drop between 12:59 and 1:00 comes back into the input tray last.  After observing my own clock carefully and stepping through the YouTube video, I feel confident that the last ball to drop between 12:59 and 1:00 actually cycles back to the input tray just *before* the balls in the hour rail.  I found it fascinating that this one little difference had a huge effect on the simulation results.

Writing this little simulator taught me a lot about macOS programming.  I got to practice with tableView delegates, segues, data structures, Swift syntax, parallel processing using Grand Central Dispatch, and much more.  You can learn, too, because I put the source files for the project on GitHub.  All you have to do is open Xcode, select `Source Control > Clone...`, copy this link to my [GitHub Repository](https://github.com/geozeke/ballClockSimulator.git), paste it into the repository location field and follow the prompts to create your own copy.

Enjoy :-)