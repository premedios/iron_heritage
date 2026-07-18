import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor")

    productFlavors {
        create("dev") {
            dimension = "flavor"
            applicationId = "com.pedroremedios.ironheritage.dev"
            resValue(type = "string", name = "app_name", value = "Iron Heritage Dev")
        }
        create("prod") {
            dimension = "flavor"
            applicationId = "com.pedroremedios.ironheritage"
            resValue(type = "string", name = "app_name", value = "Iron Heritage")
        }
    }

    buildFeatures.resValues = true
}