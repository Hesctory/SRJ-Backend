using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Application.UseCases;

public class EnrollStudentUseCase
{
    private readonly CreateStudentUseCase _createStudentUseCase;
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly ISchoolYearRepository _schoolYearRepository;

    public EnrollStudentUseCase(
        CreateStudentUseCase createStudentUseCase,
        IEnrollmentRepository enrollmentRepository,
        ISchoolYearRepository schoolYearRepository)
    {
        _createStudentUseCase = createStudentUseCase;
        _enrollmentRepository = enrollmentRepository;
        _schoolYearRepository = schoolYearRepository;
    }

    public async Task<EnrollResultDTO> ExecuteAsync(EnrollStudentDTO dto)
    {
        if (!await _schoolYearRepository.IsOpenAsync(dto.Enrollment.SchoolYearId))
            throw new DomainException("YEAR_NOT_OPEN", "El año escolar no está abierto para matrícula.");

        var sectionSchoolYearId = await _enrollmentRepository.GetSchoolYearIdForSectionAsync(dto.Enrollment.SectionId);
        if (sectionSchoolYearId != dto.Enrollment.SchoolYearId)
            throw new DomainException("INVALID_GRADE_OFFERING", "La sección no corresponde al año escolar seleccionado.");

        if (await _enrollmentRepository.ExistsForStudentInYearAsync(0, dto.Enrollment.SchoolYearId))
            throw new DomainException("YEAR_ALREADY_ENROLLED", "El estudiante ya está matriculado en este año escolar.");

        var studentId = await _createStudentUseCase.ExecuteAsync(dto.Student);

        var codeNumber = await _enrollmentRepository.NextCodeNumberForYearAsync(dto.Enrollment.SchoolYearId);
        var code = $"E{dto.Enrollment.SchoolYearId % 100:D2}{codeNumber:D4}";

        var schoolFeeConceptId = 1;

        var enrollment = new DEnrollment(
            0,
            studentId,
            dto.Enrollment.SectionId,
            schoolFeeConceptId,
            code,
            codeNumber);

        var enrollmentId = await _enrollmentRepository.CreateAsync(enrollment);

        return new EnrollResultDTO
        {
            StudentId = studentId,
            EnrollmentId = enrollmentId
        };
    }
}