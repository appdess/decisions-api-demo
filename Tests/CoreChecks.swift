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
        for category in DecisionPolicy.bavarianCategories {
            r = DecisionPolicy.fixture(.bavarian); r.answers[1].choice = category
            r.answers[1].probabilities = DecisionPolicy.bavarianCategories.map { .init(value:$0,probability:$0 == category ? 0.97 : 0.01) }
            let decision = DecisionPolicy.route(.bavarian,r)
            check(decision.outcome == (category == "unclear" ? .review : .positive),"comparison classification")
            check(decision.photoIndex == (category == "photo_a" ? 0 : category == "photo_b" ? 1 : nil),"winner maps to the correct photo")
            if category == "similar" { check(decision.title == "About the same","recognizable subjects can tie") }
            r.answers[1].probabilities?.removeLast()
            check(DecisionPolicy.route(.bavarian,r).outcome == .review,"incomplete comparison distribution")
        }
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].confidence = 0.5
        check(DecisionPolicy.route(.bavarian,r).outcome == .review,"uncertain comparison")
        for probability in [0.79,0.8] {
            r = DecisionPolicy.fixture(.bavarian)
            r.answers[1].probabilities = DecisionPolicy.bavarianCategories.map { .init(value:$0,probability:$0 == "photo_a" ? probability : (1-probability)/3) }
            check(DecisionPolicy.route(.bavarian,r).outcome == (probability >= 0.8 ? .positive : .review),"comparison probability boundary")
        }
        for confidence: Double? in [nil,0.59,1.01,.nan,.infinity] {
            r = DecisionPolicy.fixture(.bavarian); r.answers[1].confidence = confidence
            check(DecisionPolicy.route(.bavarian,r).outcome == .review,"invalid comparison confidence")
        }
        for confidence in [0.6,1.0] {
            r = DecisionPolicy.fixture(.bavarian); r.answers[1].confidence = confidence
            check(DecisionPolicy.route(.bavarian,r).outcome == .positive,"valid comparison confidence boundary")
        }
        for probability in [-0.01,1.01,Double.nan,Double.infinity] {
            r = DecisionPolicy.fixture(.bavarian); r.answers[1].probabilities?[0].probability = probability
            check(DecisionPolicy.route(.bavarian,r).outcome == .review,"invalid comparison probability")
        }
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].probabilities?[3].value = "photo_a"
        check(DecisionPolicy.route(.bavarian,r).outcome == .review,"duplicate comparison option")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].probabilities?[0].probability = 0.5
        check(DecisionPolicy.route(.bavarian,r).outcome == .review,"comparison probabilities must sum to one")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].choice = "pretzel"
        check(DecisionPolicy.route(.bavarian,r).outcome == .review,"unknown comparison category")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].type = "refusal"
        check(DecisionPolicy.route(.bavarian,r).outcome == .review,"comparison refusal")
        r = DecisionPolicy.fixture(.bavarian); r.answers.reverse()
        check(DecisionPolicy.route(.bavarian,r).photoIndex == 0,"comparison answers can arrive out of order")
        let samplePrediction = DecisionPolicy.route(.bavarian,DecisionPolicy.fixture(.bavarian)).prediction
        check(samplePrediction?.probability(for:"photo_a") == 0.97,"display the actual Photo A probability")
        check(samplePrediction?.probability(for:"photo_b") == 0.01,"do not renormalize away tie and unclear probability")
        check(samplePrediction?.confidence == 0.9,"confidence remains separate from selected-option probability")
        r = DecisionPolicy.fixture(.bavarian)
        r.answers[1].probabilities = [.init(value:"photo_b",probability:0.30),.init(value:"similar",probability:0.10),.init(value:"photo_a",probability:0.55),.init(value:"unclear",probability:0.05)]
        let uncertainPrediction = DecisionPolicy.route(.bavarian,r)
        check(uncertainPrediction.outcome == .review && uncertainPrediction.photoIndex == nil,"uncertain prediction must not claim an accepted winner")
        check(uncertainPrediction.prediction?.probability(for:"photo_a") == 0.55,"valid probabilities remain visible during manual review regardless of response order")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].confidence = 0.59
        check(DecisionPolicy.route(.bavarian,r).prediction?.confidence == 0.59,"low confidence remains visible without accepting the prediction")
        r = DecisionPolicy.fixture(.bavarian); r.answers[0].probability = 0.79
        check(DecisionPolicy.route(.bavarian,r).outcome == .review && DecisionPolicy.route(.bavarian,r).prediction != nil,"poor visibility keeps the prediction visible but requires review")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].probabilities?[0].probability = .nan
        check(DecisionPolicy.route(.bavarian,r).prediction == nil,"never display malformed probabilities")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].type = "refusal"
        check(DecisionPolicy.route(.bavarian,r).prediction == nil,"never invent probabilities for a refusal")
        r = DecisionPolicy.fixture(.bavarian); r.answers[1].choice = "unclear"
        r.answers[1].probabilities = DecisionPolicy.bavarianCategories.map { .init(value:$0,probability:$0 == "unclear" ? 0.97 : 0.01) }
        check(DecisionPolicy.route(.bavarian,r).outcome == .review && DecisionPolicy.route(.bavarian,r).prediction?.choice == "unclear","an unclear prediction remains visible and requires review")
        let pairData = try DecisionPolicy.request(.bavarian,jpeg:Data([11]),comparisonJPEG:Data([22]))
        let pairJSON = try JSONSerialization.jsonObject(with:pairData) as! [String:Any]
        let pairInput = pairJSON["input"] as! [[String:Any]]
        let pairContent = pairInput[0]["content"] as! [[String:Any]]
        let images = pairContent.filter { $0["type"] as? String == "input_image" }
        check(images.count == 2,"comparison sends exactly two images")
        check(images[0]["image_url"] as? String == "data:image/jpeg;base64,Cw==","first image is Photo A")
        check(images[1]["image_url"] as? String == "data:image/jpeg;base64,Fg==","second image is Photo B")
        check(pairContent[1]["text"] as? String == "Photo A:" && pairContent[3]["text"] as? String == "Photo B:","photos are labeled immediately before their images")
        check((pairJSON["questions"] as? [[String:Any]])?.count == 2,"comparison quality and cultural choice are separate questions")
        for (mode,first,second) in [(BakeryMode.bavarian,Data([1]),nil as Data?),(.bavarian,Data(),Data([2])),(.bavarian,Data([1]),Data()),(.bavarian,Data([1]),Data(repeating:0,count:3_000_001)),(.binary,Data([1]),Data([2]))] {
            do { _ = try DecisionPolicy.request(mode,jpeg:first,comparisonJPEG:second); check(false,"invalid photo count or data must be rejected") }
            catch is DemoError { check(true,"invalid image request rejected") }
        }
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
