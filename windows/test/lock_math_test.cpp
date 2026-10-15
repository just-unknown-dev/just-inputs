#include <gtest/gtest.h>

#include "lock_math.h"

namespace just_inputs {
namespace test {

TEST(MotionAccumulator, RelativeMovementAddsUpAndStartsAgain) {
  MotionAccumulator motion;
  double dx = 0;
  double dy = 0;
  EXPECT_FALSE(motion.Take(&dx, &dy));

  motion.AddRelative(3, -2);
  motion.AddRelative(1, 5);
  ASSERT_TRUE(motion.Take(&dx, &dy));
  EXPECT_EQ(dx, 4);
  EXPECT_EQ(dy, 3);
  EXPECT_TRUE(motion.IsEmpty());
  EXPECT_FALSE(motion.Take(&dx, &dy));
}

TEST(MotionAccumulator, MovementThatCancelsOutSendsNothing) {
  MotionAccumulator motion;
  motion.AddRelative(5, 0);
  motion.AddRelative(-5, 0);
  double dx = 0;
  double dy = 0;
  EXPECT_FALSE(motion.Take(&dx, &dy));
}

TEST(MotionAccumulator, AbsolutePositionsMoveByTheirDifference) {
  MotionAccumulator motion;
  double dx = 0;
  double dy = 0;
  motion.AddAbsolute(100, 50);
  EXPECT_FALSE(motion.Take(&dx, &dy)) << "the first only says where it is";
  motion.AddAbsolute(110, 45);
  motion.AddAbsolute(112.5, 45);
  ASSERT_TRUE(motion.Take(&dx, &dy));
  EXPECT_DOUBLE_EQ(dx, 12.5);
  EXPECT_DOUBLE_EQ(dy, -5);
}

TEST(MotionAccumulator, ResetForgetsWhereAnAbsoluteSourceWas) {
  MotionAccumulator motion;
  motion.AddAbsolute(100, 100);
  motion.AddRelative(7, 7);
  motion.Reset();
  motion.AddAbsolute(400, 400);
  double dx = 0;
  double dy = 0;
  EXPECT_FALSE(motion.Take(&dx, &dy));
}

TEST(AbsoluteToPixels, SpansTheScreen) {
  EXPECT_DOUBLE_EQ(AbsoluteToPixels(0, 1920), 0);
  EXPECT_DOUBLE_EQ(AbsoluteToPixels(65535, 1920), 1920);
  EXPECT_NEAR(AbsoluteToPixels(32768, 1920), 960, 0.1);
}

TEST(CentreClip, TwoByTwoAtTheCentre) {
  const RECT clip = CentreClip(RECT{100, 200, 900, 800});
  EXPECT_EQ(clip.left, 499);
  EXPECT_EQ(clip.top, 499);
  EXPECT_EQ(clip.right, 501);
  EXPECT_EQ(clip.bottom, 501);
  EXPECT_FALSE(IsEmptyClip(clip));
}

TEST(CentreClip, AWindowWithNoSizeHoldsNothing) {
  EXPECT_TRUE(IsEmptyClip(CentreClip(RECT{50, 50, 50, 80})));
  EXPECT_TRUE(IsEmptyClip(RECT{0, 0, 0, 0}));
}

}  // namespace test
}  // namespace just_inputs
