plugins {
    kotlin("jvm")
    kotlin("kapt")
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
    id("java-library")
}

group = "com.nugusauce"
version = "0.0.1-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    api("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.postgresql:postgresql")
    implementation("com.querydsl:querydsl-jpa:5.1.0:jakarta")
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.5.4"))
    kapt("com.querydsl:querydsl-apt:5.1.0:jakarta")
    kapt("jakarta.annotation:jakarta.annotation-api:2.1.1")
    kapt("jakarta.persistence:jakarta.persistence-api:3.1.0")
    testImplementation("com.h2database:h2")
    testImplementation("org.jetbrains.kotlin:kotlin-reflect")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

sourceSets["main"].java.srcDir("build/generated/source/kapt/main")

tasks.test {
    useJUnitPlatform()
}
kotlin {
    jvmToolchain(21)
}
