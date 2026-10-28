import Foundation
@main struct CoreChecks {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message:String) { precondition(condition(),message); count += 1 }
        check(DecisionPolicy.route(.binary,DecisionPolicy.fixture(.binary)).title == "Pretzel","binary fixture")
        check(DecisionPolicy.route(.choice,DecisionPolicy.fixture(.choice)).title == "Pretzel","choice fixture")
        check(DecisionPolicy.route(.packing,DecisionPolicy.fixture(.packing)).title == "Check the order","packing negative")
        for mode in BakeryMode.allCases {
            check(DecisionPolicy.route(mode,.init(answers:[])).title == "Check manually","empty answers")
            var r = DecisionPolicy.fixture(mode); r.answers[0].type = "refusal"
            check(DecisionPolicy.route(mode,r).title == "Check manually","refusal")
            r = DecisionPolicy.fixture(mode); r.answers[0].probability = .nan
            check(DecisionPolicy.route(mode,r).title == "Check manually","NaN")
            r = DecisionPolicy.fixture(mode); r.answers[0].probability = 0.79
            check(DecisionPolicy.route(mode,r).title == "Check manually","unclear")
        }
        var r = DecisionPolicy.fixture(.choice); r.answers[1].probability = 0.2
        check(DecisionPolicy.route(.choice,r).title == "Check manually","multiple items still need a single category in Classify")
        r = DecisionPolicy.fixture(.binary); r.answers[r.answers.count - 1].probability = 0.5
        check(DecisionPolicy.route(.binary,r).title == "Check manually","middle")
        r = DecisionPolicy.fixture(.choice); r.answers[2].confidence = 0.59
        check(DecisionPolicy.route(.choice,r).title == "Check manually","confidence")
        r = DecisionPolicy.fixture(.choice); r.answers[2].probabilities = []
        check(DecisionPolicy.route(.choice,r).title == "Check manually","malformed distribution")
        r = DecisionPolicy.fixture(.binary); r.answers[1].name = "clear"
        check(DecisionPolicy.route(.binary,r).title == "Check manually","duplicate name")
        check(DecisionPolicy.route(.binary,DecisionPolicy.fixture(.binary)).outcome == .positive,"positive signal")
        check(DecisionPolicy.route(.packing,DecisionPolicy.fixture(.packing)).outcome == .negative,"negative packing signal")
        r = DecisionPolicy.fixture(.binary); r.answers[r.answers.count - 1].probability = 0.1
        check(DecisionPolicy.route(.binary,r).outcome == .negative,"negative binary signal")
        r.answers[r.answers.count - 1].probability = 0.5
        check(DecisionPolicy.route(.binary,r).outcome == .review,"uncertainty must not show red or green")
        r.answers[0].probability = 0.1
        check(DecisionPolicy.route(.binary,r).outcome == .review,"unclear view must not show red")
        for category in ["doughnut", "cookie", "bread_roll"] {
            r = DecisionPolicy.fixture(.choice); r.answers[2].choice = category
            r.answers[2].probabilities = DecisionPolicy.categories.map { .init(value:$0,probability:$0 == category ? 0.95 : 0.01) }
            check(DecisionPolicy.route(.choice,r).title == DecisionPolicy.labels[category],"expanded category")
            r.answers[2].probabilities?.removeLast()
            check(DecisionPolicy.route(.choice,r).outcome == .review,"incomplete six-category distribution")
        }
        check((DecisionPolicy.questions(.choice)[2]["choices"] as? [[String:String]])?.count == 6,"six choices sent to API")
        for category in DecisionPolicy.crowdCategories {
            r = DecisionPolicy.fixture(.crowd); r.answers[1].choice = category
            r.answers[1].probabilities = DecisionPolicy.crowdCategories.map { .init(value:$0,probability:$0 == category ? 0.97 : 0.01) }
            check(DecisionPolicy.route(.crowd,r).outcome == (category == "unclear" ? .review : .positive),"gesture classification")
            r.answers[1].probabilities?.removeLast()
            check(DecisionPolicy.route(.crowd,r).outcome == .review,"incomplete gesture distribution")
        }
        r = DecisionPolicy.fixture(.crowd); r.answers[1].confidence = 0.5
        check(DecisionPolicy.route(.crowd,r).outcome == .review,"uncertain gestures")
        let data = try DecisionPolicy.request(.choice,jpeg:Data([1,2,3]))
        let json = try JSONSerialization.jsonObject(with:data) as! [String:Any]
        check(json["model"] as? String == "gpt-6-luna","model")
        check((json["questions"] as? [[String:Any]])?.count == 3,"question count")
        // A recognizable non-food subject is a valid negative/other result.
        r = DecisionPolicy.fixture(.binary); r.answers[r.answers.count - 1].probability = 0.01
        check(DecisionPolicy.route(.binary,r).title == "Not a pretzel","clear non-food binary negative")
        r = DecisionPolicy.fixture(.choice); r.answers[2].choice = "other"
        r.answers[2].probabilities = DecisionPolicy.categories.map { .init(value:$0,probability:$0 == "other" ? 0.95 : 0.01) }
        check(DecisionPolicy.route(.choice,r).title == "Other","clear non-food choice")
        r.answers[0].probability = 0.1
        check(DecisionPolicy.route(.choice,r).outcome == .review,"truly unclear other still needs review")

        // Binary presence detection accepts a clear scene without a single-item answer.
        // These synthetic API answers test app routing, not model image accuracy.
        let scene = Data("""
        {"answers":[
          {"type":"predicate","name":"pretzel","probability":0.01},
          {"type":"predicate","name":"clear","probability":0.97}
        ]}
        """.utf8)
        let noPretzel = try JSONDecoder().decode(DecisionResponse.self,from:scene)
        check(DecisionPolicy.route(.binary,noPretzel).title == "Not a pretzel","clear scene with several non-pretzel items")
        for (probability,outcome) in [(0.0,DecisionOutcome.negative),(0.2,.negative),(0.2001,.review),(0.5,.review),(0.7999,.review),(0.8,.positive),(1.0,.positive)] {
            r = noPretzel; r.answers[0].probability = probability
            check(DecisionPolicy.route(.binary,r).outcome == outcome,"scene presence threshold \(probability)")
            r.answers[1].probability = 0.79
            check(DecisionPolicy.route(.binary,r).outcome == .review,"unclear scene must not produce yes or no")
        }
        for probability: Double? in [nil,-0.01,1.01,.nan,.infinity] {
            r = noPretzel; r.answers[0].probability = probability
            check(DecisionPolicy.route(.binary,r).outcome == .review,"invalid pretzel probability")
        }
        r = noPretzel; r.answers[0].type = "refusal"
        check(DecisionPolicy.route(.binary,r).outcome == .review,"refused scene presence")
        r = noPretzel; r.answers.removeFirst()
        check(DecisionPolicy.route(.binary,r).outcome == .review,"missing scene presence")
        r = noPretzel; r.answers.append(Answer(type:"predicate",name:"single",probability:0.01))
        check(DecisionPolicy.route(.binary,r).outcome == .review,"unexpected legacy answer")
        let binaryData = try DecisionPolicy.request(.binary,jpeg:Data([1,2,3]))
        let binaryJSON = try JSONSerialization.jsonObject(with:binaryData) as! [String:Any]
        let binaryQuestions = binaryJSON["questions"] as! [[String:Any]]
        check(binaryQuestions.compactMap { $0["name"] as? String } == ["clear","pretzel"],"binary request asks about quality and presence without item count")
        print("Passed \(count) native policy checks.")
    }
}
