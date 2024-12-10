# MUSI-6104-Integrat-Mus-Multimedia-Final-Project-Work-Music-Hide
AR-based multiplayer musical treasure hunt

Is there a relationship between architecture, music, and human cognition?

## Description ##
- We built an AR-based multiplayer musical treasure hunt. We used
Apple’s AR frameworks - RealityKit and ARKit for development and
our target devices were iPhones and iPads.
- This game was developed to be a ‘Participant’ DGD1 category, but it’s
interesting that we noticed people playing it as a ‘Wanderer’ where
even though they found all the chords, they’d still go around to
explore the environment.

## Game Flow ##
The game has two roles for players - hider and seeker. The player that
opens the game and starts the session becomes the hider by default and
the player that joins the session is the seeker.
- The hider can move around the physical space with their device and
place 4 chords (C/F/G/Amin) in various locations, preferably far apart
from each other. The chords are always placed on a flat surface
utilizing the plane detection capabilities of the framework to increase
augmented realism.
- The seeker can join the session by bringing their device close to the
hider’s device. The game shows interactive instructions to make sure
the two devices are connected and have successfully been able to synchronize their AR worlds. This is done using ARKit along with the
Multipeer Connectivity framework for continuous wireless
transmission between the devices.
- The objective of the seeker is to find all the chords using auditory
cues. The 4 chords act as invisible spatialized sound sources in the
physical space i.e. chords that are nearby will sound louder than ones
that are far away.
- Once the seeker feels they are close to a chord, they can tap the
screen and the game makes the chord visible if they were close
enough to it, otherwise the game tells you that there are no chords
around.

## Challenges and Changes ##
- Fixing errors related to wireless synchronization of AR maps between
devices was tricky and had bugs. (Some are still there)
- Setting up the parameters and choosing appropriate samples for
spatial audio sound so that users could distinguish sounds was
challenging. Overall, I think this worked fairly well since we saw users
being able to isolate sound sources during the neo-arcade event.

## Collaboration ##
- Dhruv: Worked on the technical design and programming of the game
- Changda: Game theme ideation, how to involve musical ideas, 3D
modeling, assist programming


## Video ##

<a href="https://www.youtube.com/watch?v=w4bzvwgM4Jw" target="_blank" rel="noopener noreferrer">
    <img src="https://img.youtube.com/vi/w4bzvwgM4Jw/maxresdefault.jpg" width="480" alt="Video Title: A Walkthrough" class="off-glb">
</a>



## Future Plan ##

![image](https://github.com/user-attachments/assets/b2bcdb56-cdff-426c-bb70-1d3bf49ebd48)
