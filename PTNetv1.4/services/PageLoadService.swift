import Foundation

class PageLoadService {
    func pageLoadTimer(address: String) -> PageLoadDTO {
        let startTime = Date()

        guard let url = URL(string: address) else {
            return PageLoadDTO(data: "", status: "Error", statusCode: 0, responseTime: -1, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let session = URLSession.shared
        var apiResponse: PageLoadDTO = PageLoadDTO(data: "", status: "Error", statusCode: 0, responseTime: -1, message: "Unknown error")

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                apiResponse = PageLoadDTO(data: "", status: "Error", statusCode: 0, responseTime: -1, message: "Request error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                apiResponse = PageLoadDTO(data: "", status: "Error", statusCode: 0, responseTime: -1, message: "Invalid response")
                return
            }

            let endTime = Date()
            let responseTimeSecond = endTime.timeIntervalSince(startTime)
            let responseTime = round(responseTimeSecond * 1000000) / 1000


            switch httpResponse.statusCode {
            case 200:
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    apiResponse = PageLoadDTO(data: responseString, status: "Success", statusCode: 200, responseTime: responseTime, message: "Success")
                } else {
                    apiResponse = PageLoadDTO(data: "", status: "Error", statusCode: 200, responseTime: responseTime, message: "Invalid data")
                }
            case 400:
                apiResponse = PageLoadDTO(data: "", status: "Error", statusCode: 400, responseTime: responseTime, message: "Bad request")
            default:
                apiResponse = PageLoadDTO(data: "", status: "Error", statusCode: httpResponse.statusCode, responseTime: responseTime, message: "HTTP response status code: \(httpResponse.statusCode)")
            }
        }
        dataTask.resume()

        semaphore.wait()

        return apiResponse
    }
}
