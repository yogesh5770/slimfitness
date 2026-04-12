class VitalsService {
  /// Calculates BMI based on weight (kg) and height (cm).
  static double calculateBMI(double weight, double heightCm) {
    if (heightCm <= 0) return 0;
    double heightM = heightCm / 100;
    return weight / (heightM * heightM);
  }

  /// Categorizes BMI into a human-readable status.
  static String getBMIStatus(double bmi) {
    if (bmi < 18.5) return 'UNDERWEIGHT';
    if (bmi < 25) return 'NORMAL';
    if (bmi < 30) return 'OVERWEIGHT';
    return 'OBESE';
  }

  /// Calculates Daily Calorie Target using Mifflin-St Jeor Equation.
  /// Goal can be: 'fat_loss', 'maintenance', 'muscle_gain'
  static int calculateDailyCalories({
    required double weight,
    required double heightCm,
    required int age,
    required bool isMale,
    required String goal,
  }) {
    // BMR Calculation
    double bmr;
    if (isMale) {
      bmr = (10 * weight) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * heightCm) - (5 * age) - 161;
    }

    // TDEE (Total Daily Energy Expenditure) - Assuming Moderate Activity (1.55 multiplier)
    double tdee = bmr * 1.55;

    // Adjust based on goal
    if (goal == 'fat_loss') {
      return (tdee - 500).round();
    } else if (goal == 'muscle_gain') {
      return (tdee + 300).round();
    } else {
      return tdee.round();
    }
  }

  /// Calculates Macro Splits based on weight and goal.
  /// Returns {protein, carbs, fats} in grams.
  static Map<String, int> calculateMacros({
    required int totalCalories,
    required double weight,
    required String goal,
  }) {
    double proteinPerKg;
    double fatPercentage;

    if (goal == 'muscle_gain') {
      proteinPerKg = 2.2;
      fatPercentage = 0.25;
    } else if (goal == 'fat_loss') {
      proteinPerKg = 2.0;
      fatPercentage = 0.20;
    } else {
      proteinPerKg = 1.8;
      fatPercentage = 0.25;
    }

    int proteinGrams = (weight * proteinPerKg).round();
    int fatGrams = ((totalCalories * fatPercentage) / 9).round();
    
    int proteinCals = proteinGrams * 4;
    int fatCals = fatGrams * 9;
    int carbCals = totalCalories - proteinCals - fatCals;
    int carbGrams = (carbCals / 4).round();

    return {
      'protein': proteinGrams,
      'carbs': carbGrams,
      'fats': fatGrams,
    };
  }

  /// Estimates Body Fat % using the Deurenberg Formula
  static double calculateBodyFat(double bmi, int age, bool isMale) {
    if (bmi <= 0) return 0;
    int genderFactor = isMale ? 1 : 0;
    return (1.20 * bmi) + (0.23 * age) - (10.8 * genderFactor) - 5.4;
  }

  /// Calculates Ideal Body Weight using the Devine Formula
  static double calculateIdealWeight(double heightCm, bool isMale) {
    if (heightCm < 152.4) return isMale ? 50.0 : 45.5; // Floor at 5ft
    double inchesOver5ft = (heightCm - 152.4) / 2.54;
    double baseWeight = isMale ? 50.0 : 45.5;
    return baseWeight + (2.3 * inchesOver5ft);
  }
}
